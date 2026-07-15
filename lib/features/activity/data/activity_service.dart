import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Одно событие активности: кто-то лайкнул или прокомментировал мой пост.
class ActivityItem {
  const ActivityItem({
    required this.type,
    required this.userName,
    required this.postId,
    required this.postName,
    this.userPhotoUrl,
    this.text,
    this.createdAt,
  });

  final ActivityType type;
  final String userName;
  final String? userPhotoUrl;
  final String postId;
  final String postName;

  /// Текст комментария (для type == comment).
  final String? text;
  final DateTime? createdAt;
}

enum ActivityType { like, comment }

/// Сборщик «активности» без серверных пушей (Spark-план: Cloud Functions
/// не выполняются). Схема: берём последние посты пользователя и читаем
/// свежие лайки/комментарии из их подколлекций. Стоимость — пара десятков
/// point-read'ов на открытие экрана, для текущего масштаба ок.
///
/// «Новое/просмотрено» отслеживается меткой последнего визита в
/// SharedPreferences (`activity_last_seen`).
@lazySingleton
class ActivityService {
  ActivityService(this._firestore);

  final FirebaseFirestore _firestore;

  static const String _lastSeenKey = 'activity_last_seen';

  Future<List<ActivityItem>> fetchActivity(
    String userId, {
    int postsLimit = 12,
    int perPostLimit = 10,
  }) async {
    final postsSnap = await _firestore
        .collection('posts')
        .where('authorId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(postsLimit)
        .get();

    final futures = <Future<List<ActivityItem>>>[];
    for (final doc in postsSnap.docs) {
      final postName = (doc.data()['drinkName'] as String?) ?? 'Банка';
      futures
        ..add(_fetchLikes(doc.id, postName, userId, perPostLimit))
        ..add(_fetchComments(doc.id, postName, userId, perPostLimit));
    }

    final results = await Future.wait(futures);
    final items = results.expand((r) => r).toList()
      ..sort((a, b) {
        final ad = a.createdAt;
        final bd = b.createdAt;
        if (ad == null || bd == null) return ad == null ? 1 : -1;
        return bd.compareTo(ad);
      });
    return items.length > 60 ? items.sublist(0, 60) : items;
  }

  Future<List<ActivityItem>> _fetchLikes(
    String postId,
    String postName,
    String selfId,
    int limit,
  ) async {
    final snap = await _firestore
        .collection('posts')
        .doc(postId)
        .collection('likes')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return [
      for (final d in snap.docs)
        if (d.id != selfId)
          ActivityItem(
            type: ActivityType.like,
            userName: (d.data()['userName'] as String?) ?? 'Кто-то',
            userPhotoUrl: d.data()['userPhotoUrl'] as String?,
            postId: postId,
            postName: postName,
            createdAt: (d.data()['createdAt'] as Timestamp?)?.toDate(),
          ),
    ];
  }

  Future<List<ActivityItem>> _fetchComments(
    String postId,
    String postName,
    String selfId,
    int limit,
  ) async {
    final snap = await _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return [
      for (final d in snap.docs)
        if ((d.data()['authorId'] as String?) != selfId)
          ActivityItem(
            type: ActivityType.comment,
            userName: (d.data()['authorName'] as String?) ?? 'Кто-то',
            userPhotoUrl: d.data()['authorPhotoUrl'] as String?,
            postId: postId,
            postName: postName,
            text: d.data()['text'] as String?,
            createdAt: (d.data()['createdAt'] as Timestamp?)?.toDate(),
          ),
    ];
  }

  /// Есть ли в [items] события новее последнего визита.
  Future<bool> hasUnseen(List<ActivityItem> items) async {
    final newest = items.isNotEmpty ? items.first.createdAt : null;
    if (newest == null) return false;
    final prefs = await SharedPreferences.getInstance();
    final seenMs = prefs.getInt(_lastSeenKey) ?? 0;
    return newest.millisecondsSinceEpoch > seenMs;
  }

  /// Отметить активность просмотренной (зовётся при открытии экрана).
  Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastSeenKey, DateTime.now().millisecondsSinceEpoch);
  }
}
