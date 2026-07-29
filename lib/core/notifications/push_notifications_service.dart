import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:injectable/injectable.dart';

/// Push-уведомления (FCM).
///
/// Как это работает целиком:
/// 1. Клиент (этот сервис) спрашивает разрешение, получает FCM-токен
///    устройства и кладёт его в `users/{uid}.fcmTokens` (arrayUnion).
///    При выходе из аккаунта токен убирается (arrayRemove), иначе пуши
///    прилетали бы следующему владельцу устройства.
/// 2. Отправляет уведомления **сервер** — Cloud Functions (`functions/`),
///    триггеры `onLikeCreated` / `onCommentCreated` / `onPostCreated`:
///    читают токены получателей и шлют multicast через FCM.
/// 3. Приложение в фоне/закрыто — баннер рисует сама система по
///    notification-payload. Приложение открыто — баннера нет, поэтому
///    показываем локальное уведомление сами (`onMessage`).
/// 4. Тап по уведомлению отдаёт `data.postId` — в него уходит навигация
///    (см. [onOpenPost]).
///
/// ⚠️ Cloud Functions выполняются только на Blaze-плане. Пока проект на
/// Spark, клиентская часть работает (токены копятся), но отправлять
/// уведомления некому.
@lazySingleton
class PushNotificationsService {
  PushNotificationsService(this._messaging, this._firestore);

  final FirebaseMessaging _messaging;
  final FirebaseFirestore _firestore;

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  /// Должен совпадать с `default_notification_channel_id` в манифесте.
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'banka_default',
    'Уведомления banka',
    description: 'Лайки, комментарии и новые банки от ваших подписок',
    importance: Importance.high,
  );

  static const String _usersCollection = 'users';
  static const String _fcmTokensField = 'fcmTokens';

  /// Куда переходить по тапу — задаёт слой навигации (см. `BankaApp`).
  void Function(String postId)? onOpenPost;

  bool _initialized = false;
  String? _registeredUserId;
  String? _token;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onOpenedSub;

  /// Разрешения, канал уведомлений и подписка на входящие сообщения.
  /// Идемпотентно — можно звать повторно.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      await _messaging.requestPermission();

      await _local.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
        onDidReceiveNotificationResponse: (response) {
          final postId = response.payload;
          if (postId != null && postId.isNotEmpty) onOpenPost?.call(postId);
        },
      );

      await _local
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_channel);

      _onMessageSub = FirebaseMessaging.onMessage.listen(_showForeground);
      _onOpenedSub = FirebaseMessaging.onMessageOpenedApp.listen(_handleOpen);

      // Приложение запустили тапом по уведомлению из «холодного» состояния.
      final initial = await _messaging.getInitialMessage();
      if (initial != null) _handleOpen(initial);
    } catch (e, s) {
      // Push — не критичный путь: сломанные Google Play Services или
      // отсутствие сети не должны ронять старт приложения.
      debugPrint('PushNotificationsService.init failed: $e\n$s');
    }
  }

  /// Привязать токен устройства к пользователю (после логина).
  Future<void> registerFor(String userId) async {
    if (_registeredUserId == userId) return;
    await init();
    try {
      final token = await _messaging.getToken();
      if (token == null) return;
      _token = token;
      _registeredUserId = userId;
      await _saveToken(userId, token);

      await _tokenRefreshSub?.cancel();
      _tokenRefreshSub = _messaging.onTokenRefresh.listen((fresh) {
        _token = fresh;
        final uid = _registeredUserId;
        if (uid != null) unawaited(_saveToken(uid, fresh));
      });
    } catch (e) {
      debugPrint('PushNotificationsService.registerFor failed: $e');
    }
  }

  /// Отвязать токен (перед выходом из аккаунта).
  Future<void> unregister() async {
    final userId = _registeredUserId;
    final token = _token;
    _registeredUserId = null;
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
    if (userId == null || token == null) return;
    try {
      await _firestore.collection(_usersCollection).doc(userId).update({
        _fcmTokensField: FieldValue.arrayRemove(<String>[token]),
      });
    } catch (e) {
      debugPrint('PushNotificationsService.unregister failed: $e');
    }
  }

  Future<void> _saveToken(String userId, String token) async {
    try {
      await _firestore.collection(_usersCollection).doc(userId).update({
        _fcmTokensField: FieldValue.arrayUnion(<String>[token]),
      });
    } catch (e) {
      debugPrint('PushNotificationsService._saveToken failed: $e');
    }
  }

  void _showForeground(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;
    _local.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: message.data['postId'] as String?,
    );
  }

  void _handleOpen(RemoteMessage message) {
    final postId = message.data['postId'] as String?;
    if (postId != null && postId.isNotEmpty) onOpenPost?.call(postId);
  }

  Future<void> dispose() async {
    await _onMessageSub?.cancel();
    await _onOpenedSub?.cancel();
    await _tokenRefreshSub?.cancel();
  }
}
