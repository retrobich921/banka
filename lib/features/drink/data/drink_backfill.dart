import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

import '../../post/data/models/post_dto.dart';
import '../domain/entities/drink.dart';
import 'models/drink_dto.dart';

/// Одноразовая миграция: проставляет старым постам `drinkId` (ключ
/// вычислим из названия + бренда, которые в постах всегда были) и
/// наполняет агрегаты карточек `drinks/*` из истории.
///
/// Запускается с любого клиента при старте; от повторного/параллельного
/// запуска защищает claim-документ `meta/drink_backfill_v1` (transaction).
/// Каждый чанк постов коммитится одним батчем (обновления постов +
/// инкременты карточек атомарно) — при обрыве на середине уже
/// обработанные посты имеют drinkId и не пересчитываются при ретрае.
@lazySingleton
class DrinkBackfill {
  DrinkBackfill(this._firestore);

  final FirebaseFirestore _firestore;

  static const int _chunkSize = 150;

  DocumentReference<Map<String, dynamic>> get _meta =>
      _firestore.collection('meta').doc('drink_backfill_v1');

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

      await _run();

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

  Future<void> _run() async {
    final snap = await _firestore.collection('posts').get();
    final pending = snap.docs
        .where((d) => (d.data()[PostDto.fDrinkId] as String?) == null)
        .toList();
    if (pending.isEmpty) return;

    for (var i = 0; i < pending.length; i += _chunkSize) {
      final chunk = pending.sublist(
        i,
        i + _chunkSize > pending.length ? pending.length : i + _chunkSize,
      );
      final batch = _firestore.batch();

      // Агрегаты чанка группируем в памяти, чтобы не писать один
      // drink-документ десятки раз в одном батче.
      final drinkUpdates = <String, Map<String, dynamic>>{};

      for (final doc in chunk) {
        final post = PostDto.fromMap(doc.id, doc.data());
        final drinkId = drinkKeyOf(post.drinkName, post.brandId);
        batch.update(doc.reference, <String, dynamic>{
          PostDto.fDrinkId: drinkId,
        });

        final agg = drinkUpdates.putIfAbsent(
          drinkId,
          () => <String, dynamic>{
            DrinkDto.fName: post.drinkName,
            DrinkDto.fBrandId: ?post.brandId,
            DrinkDto.fBrandName: ?post.brandName,
            '_posts': 0,
            '_ratingSum': 0.0,
            '_ratingCount': 0,
            '_thumb': null,
          },
        );
        agg['_posts'] = (agg['_posts'] as int) + 1;
        if (post.rating != null) {
          agg['_ratingSum'] =
              (agg['_ratingSum'] as double) + post.rating!.score;
          agg['_ratingCount'] = (agg['_ratingCount'] as int) + 1;
        }
        if (post.photos.isNotEmpty) {
          agg['_thumb'] = post.photos.first.thumbUrl;
        }
      }

      for (final entry in drinkUpdates.entries) {
        final agg = entry.value;
        batch.set(
          _firestore.collection('drinks').doc(entry.key),
          <String, dynamic>{
            DrinkDto.fName: agg[DrinkDto.fName],
            if (agg[DrinkDto.fBrandId] != null)
              DrinkDto.fBrandId: agg[DrinkDto.fBrandId],
            if (agg[DrinkDto.fBrandName] != null)
              DrinkDto.fBrandName: agg[DrinkDto.fBrandName],
            if (agg['_thumb'] != null) DrinkDto.fThumbUrl: agg['_thumb'],
            DrinkDto.fPostsCount: FieldValue.increment(agg['_posts'] as int),
            if ((agg['_ratingCount'] as int) > 0) ...{
              DrinkDto.fRatingSum: FieldValue.increment(
                agg['_ratingSum'] as double,
              ),
              DrinkDto.fRatingCount: FieldValue.increment(
                agg['_ratingCount'] as int,
              ),
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
