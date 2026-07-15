import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

import '../../post/data/models/post_dto.dart';
import '../domain/entities/drink.dart';
import 'models/drink_dto.dart';

/// Одноразовая миграция карточек напитков (v2).
///
/// v1 строила ключ карточки из названия поста — а названия оказались
/// свободным творчеством («я хз что писать»), и каждый пост становился
/// отдельным «напитком». v2 пересобирает всё по структурным полям:
/// карточка = **бренд + вкус**; посты без бренда/вкуса в карточки не
/// попадают.
///
/// Шаги: снести все документы `drinks/*` → пересчитать `drinkId` у всех
/// постов (проставить новый или удалить, если бренд/вкус не выбраны) →
/// пересобрать агрегаты (посты, оценки, цены, магазины, обложки).
/// От повторного/параллельного запуска защищает claim-документ
/// `meta/drink_backfill_v2` (transaction).
@lazySingleton
class DrinkBackfill {
  DrinkBackfill(this._firestore);

  final FirebaseFirestore _firestore;

  static const int _chunkSize = 150;

  // v3: как v2, но архивные посты не учитываются в агрегатах
  // (drinkId им всё равно проставляется — нужен для возврата из архива).
  DocumentReference<Map<String, dynamic>> get _meta =>
      _firestore.collection('meta').doc('drink_backfill_v3');

  /// Безопасно вызывать при каждом старте: если миграция уже выполнена
  /// или выполняется другим клиентом — сразу выходит.
  Future<void> runIfNeeded() async {
    try {
      final claimed = await _firestore.runTransaction<bool>((tx) async {
        final snap = await tx.get(_meta);
        final status = snap.data()?['status'] as String?;
        if (status == 'done' || status == 'running') return false;
        tx.set(_meta, <String, dynamic>{
          'status': 'running',
          'startedAt': FieldValue.serverTimestamp(),
        });
        return true;
      });
      if (!claimed) return;

      await _wipeDrinks();
      await _rebuildFromPosts();

      await _meta.set(<String, dynamic>{
        'status': 'done',
        'finishedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Снимаем claim, чтобы следующий запуск попробовал ещё раз.
      try {
        await _meta.delete();
      } catch (_) {}
    }
  }

  /// Полная зачистка старых карточек (в т.ч. мусорных из v1).
  Future<void> _wipeDrinks() async {
    final snap = await _firestore.collection('drinks').get();
    for (var i = 0; i < snap.docs.length; i += _chunkSize) {
      final batch = _firestore.batch();
      for (final doc in snap.docs.skip(i).take(_chunkSize)) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  Future<void> _rebuildFromPosts() async {
    final snap = await _firestore.collection('posts').get();
    final docs = snap.docs;

    for (var i = 0; i < docs.length; i += _chunkSize) {
      final chunk = docs.skip(i).take(_chunkSize).toList();
      final batch = _firestore.batch();
      final drinkUpdates = <String, _DrinkAgg>{};

      for (final doc in chunk) {
        final post = PostDto.fromMap(doc.id, doc.data());
        final drinkId = drinkKeyOf(
          brandId: post.brandId,
          flavorId: post.flavorId,
        );

        if (drinkId == null) {
          // Бренд/вкус не выбраны — карточки нет; чистим старую привязку.
          if (post.drinkId != null) {
            batch.update(doc.reference, <String, dynamic>{
              PostDto.fDrinkId: FieldValue.delete(),
            });
          }
        } else {
          if (post.drinkId != drinkId) {
            batch.update(doc.reference, <String, dynamic>{
              PostDto.fDrinkId: drinkId,
            });
          }
          // Архивные посты скрыты из рецензий — в агрегаты не входят
          // (вклад вернётся при разархивировании).
          if (post.archived) continue;
          final agg = drinkUpdates.putIfAbsent(
            drinkId,
            () => _DrinkAgg(
              name: drinkDisplayName(
                brandName: post.brandName,
                flavorName: post.flavorName,
              ),
              brandId: post.brandId,
              brandName: post.brandName,
            ),
          );
          agg.posts += 1;
          if (post.rating != null) {
            agg.ratingSum += post.rating!.score;
            agg.ratingCount += 1;
          }
          if (post.price != null) {
            agg.pricesSum += post.price!;
            agg.pricesCount += 1;
          }
          final store = post.store;
          if (store != null && store.isNotEmpty) {
            agg.stores[store] = (agg.stores[store] ?? 0) + 1;
          }
          if (post.photos.isNotEmpty) {
            agg.thumbUrl = post.photos.first.thumbUrl;
          }
        }
      }

      for (final entry in drinkUpdates.entries) {
        final agg = entry.value;
        batch.set(
          _firestore.collection('drinks').doc(entry.key),
          <String, dynamic>{
            DrinkDto.fName: agg.name,
            DrinkDto.fBrandId: ?agg.brandId,
            DrinkDto.fBrandName: ?agg.brandName,
            DrinkDto.fThumbUrl: ?agg.thumbUrl,
            DrinkDto.fPostsCount: FieldValue.increment(agg.posts),
            if (agg.ratingCount > 0) ...{
              DrinkDto.fRatingSum: FieldValue.increment(agg.ratingSum),
              DrinkDto.fRatingCount: FieldValue.increment(agg.ratingCount),
            },
            if (agg.pricesCount > 0) ...{
              DrinkDto.fPricesSum: FieldValue.increment(agg.pricesSum),
              DrinkDto.fPricesCount: FieldValue.increment(agg.pricesCount),
            },
            if (agg.stores.isNotEmpty)
              DrinkDto.fStores: {
                for (final s in agg.stores.entries)
                  s.key: FieldValue.increment(s.value),
              },
            DrinkDto.fUpdatedAt: Timestamp.fromDate(DateTime.now()),
          },
          SetOptions(merge: true),
        );
      }

      await batch.commit();
    }
  }
}

class _DrinkAgg {
  _DrinkAgg({required this.name, this.brandId, this.brandName});

  final String name;
  final String? brandId;
  final String? brandName;
  String? thumbUrl;
  int posts = 0;
  double ratingSum = 0;
  int ratingCount = 0;
  double pricesSum = 0;
  int pricesCount = 0;
  final Map<String, int> stores = {};
}
