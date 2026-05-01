import 'dart:async';

import 'package:banka/core/error/failures.dart';
import 'package:banka/features/post/domain/entities/post.dart';
import 'package:banka/features/post/domain/usecases/watch_brand_feed.dart';
import 'package:banka/features/post/domain/usecases/watch_feed.dart';
import 'package:banka/features/post/domain/usecases/watch_group_feed.dart';
import 'package:banka/features/post/presentation/bloc/posts_feed_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWatchFeed extends Mock implements WatchFeed {}

class _MockWatchGroupFeed extends Mock implements WatchGroupFeed {}

class _MockWatchBrandFeed extends Mock implements WatchBrandFeed {}

void main() {
  late _MockWatchFeed watchFeed;
  late _MockWatchGroupFeed watchGroupFeed;
  late _MockWatchBrandFeed watchBrandFeed;

  setUpAll(() {
    registerFallbackValue(const WatchFeedParams());
    registerFallbackValue(const WatchGroupFeedParams(groupId: 'g'));
    registerFallbackValue(const WatchBrandFeedParams(brandId: 'b'));
  });

  setUp(() {
    watchFeed = _MockWatchFeed();
    watchGroupFeed = _MockWatchGroupFeed();
    watchBrandFeed = _MockWatchBrandFeed();
  });

  PostsFeedBloc buildBloc() =>
      PostsFeedBloc(watchFeed, watchGroupFeed, watchBrandFeed);

  Post makePost(String id) => Post(id: id, authorId: 'a', drinkName: 'd-$id');

  group('PostsFeedSubscribeRequested(global)', () {
    blocTest<PostsFeedBloc, PostsFeedState>(
      'эмитит loading → ready при успешном стриме',
      setUp: () {
        when(
          () => watchFeed(any()),
        ).thenAnswer((_) => Stream.value(Right(<Post>[makePost('p1')])));
      },
      build: buildBloc,
      act: (b) =>
          b.add(const PostsFeedSubscribeRequested(PostsFeedScope.global())),
      expect: () => [
        isA<PostsFeedState>()
            .having((s) => s.status, 'status', PostsFeedStatus.loading)
            .having((s) => s.scope?.isGlobal, 'global', true),
        isA<PostsFeedState>()
            .having((s) => s.status, 'status', PostsFeedStatus.ready)
            .having((s) => s.posts.length, 'posts', 1)
            .having((s) => s.posts.first.id, 'first id', 'p1'),
      ],
      verify: (_) {
        verify(() => watchFeed(any())).called(1);
        verifyNever(() => watchGroupFeed(any()));
      },
    );

    blocTest<PostsFeedBloc, PostsFeedState>(
      'эмитит error при Failure из стрима',
      setUp: () {
        when(() => watchFeed(any())).thenAnswer(
          (_) => Stream.value(const Left(ServerFailure(message: 'boom'))),
        );
      },
      build: buildBloc,
      act: (b) =>
          b.add(const PostsFeedSubscribeRequested(PostsFeedScope.global())),
      expect: () => [
        isA<PostsFeedState>().having(
          (s) => s.status,
          'status',
          PostsFeedStatus.loading,
        ),
        isA<PostsFeedState>()
            .having((s) => s.status, 'status', PostsFeedStatus.error)
            .having((s) => s.errorMessage, 'msg', 'boom'),
      ],
    );

    blocTest<PostsFeedBloc, PostsFeedState>(
      'повторный subscribe c тем же scope не создаёт новую подписку',
      setUp: () {
        when(
          () => watchFeed(any()),
        ).thenAnswer((_) => Stream.value(Right(<Post>[makePost('p1')])));
      },
      build: buildBloc,
      act: (b) async {
        b.add(const PostsFeedSubscribeRequested(PostsFeedScope.global()));
        await Future<void>.delayed(Duration.zero);
        b.add(const PostsFeedSubscribeRequested(PostsFeedScope.global()));
      },
      verify: (_) {
        verify(() => watchFeed(any())).called(1);
      },
    );
  });

  group('PostsFeedSubscribeRequested(group)', () {
    blocTest<PostsFeedBloc, PostsFeedState>(
      'для скоупа группы вызывает watchGroupFeed',
      setUp: () {
        when(
          () => watchGroupFeed(any()),
        ).thenAnswer((_) => Stream.value(Right(<Post>[makePost('g1')])));
      },
      build: buildBloc,
      act: (b) =>
          b.add(const PostsFeedSubscribeRequested(PostsFeedScope.group('g'))),
      expect: () => [
        isA<PostsFeedState>()
            .having((s) => s.status, 'status', PostsFeedStatus.loading)
            .having((s) => s.scope?.groupId, 'groupId', 'g'),
        isA<PostsFeedState>()
            .having((s) => s.status, 'status', PostsFeedStatus.ready)
            .having((s) => s.posts.length, 'posts', 1),
      ],
      verify: (_) {
        verify(() => watchGroupFeed(any())).called(1);
        verifyNever(() => watchFeed(any()));
      },
    );

    blocTest<PostsFeedBloc, PostsFeedState>(
      'смена scope с global на group переоткрывает подписку',
      setUp: () {
        when(
          () => watchFeed(any()),
        ).thenAnswer((_) => Stream.value(Right(<Post>[makePost('all')])));
        when(
          () => watchGroupFeed(any()),
        ).thenAnswer((_) => Stream.value(Right(<Post>[makePost('group')])));
      },
      build: buildBloc,
      act: (b) async {
        b.add(const PostsFeedSubscribeRequested(PostsFeedScope.global()));
        await Future<void>.delayed(Duration.zero);
        b.add(const PostsFeedSubscribeRequested(PostsFeedScope.group('g')));
      },
      verify: (_) {
        verify(() => watchFeed(any())).called(1);
        verify(() => watchGroupFeed(any())).called(1);
      },
    );
  });

  group('PostsFeedResetRequested', () {
    blocTest<PostsFeedBloc, PostsFeedState>(
      'отменяет подписку и сбрасывает состояние',
      setUp: () {
        when(
          () => watchFeed(any()),
        ).thenAnswer((_) => const Stream<Either<Failure, List<Post>>>.empty());
      },
      build: buildBloc,
      act: (b) async {
        b.add(const PostsFeedSubscribeRequested(PostsFeedScope.global()));
        await Future<void>.delayed(Duration.zero);
        b.add(const PostsFeedResetRequested());
      },
      expect: () => [
        isA<PostsFeedState>().having(
          (s) => s.status,
          'status',
          PostsFeedStatus.loading,
        ),
        isA<PostsFeedState>().having(
          (s) => s.status,
          'status',
          PostsFeedStatus.initial,
        ),
      ],
    );
  });
}
