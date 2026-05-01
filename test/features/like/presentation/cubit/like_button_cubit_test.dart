import 'dart:async';

import 'package:banka/core/error/failures.dart';
import 'package:banka/features/like/domain/usecases/like_post.dart';
import 'package:banka/features/like/domain/usecases/unlike_post.dart';
import 'package:banka/features/like/domain/usecases/watch_has_liked.dart';
import 'package:banka/features/like/presentation/cubit/like_button_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockLikePost extends Mock implements LikePost {}

class _MockUnlikePost extends Mock implements UnlikePost {}

class _MockWatchHasLiked extends Mock implements WatchHasLiked {}

void main() {
  late _MockLikePost likePost;
  late _MockUnlikePost unlikePost;
  late _MockWatchHasLiked watchHasLiked;

  setUpAll(() {
    registerFallbackValue(
      const LikePostParams(postId: 'p', userId: 'u', userName: 'n'),
    );
    registerFallbackValue(const UnlikePostParams(postId: 'p', userId: 'u'));
    registerFallbackValue(const WatchHasLikedParams(postId: 'p', userId: 'u'));
  });

  setUp(() {
    likePost = _MockLikePost();
    unlikePost = _MockUnlikePost();
    watchHasLiked = _MockWatchHasLiked();
  });

  LikeButtonCubit buildCubit() =>
      LikeButtonCubit(likePost, unlikePost, watchHasLiked);

  Future<void> doSubscribe(LikeButtonCubit cubit) =>
      cubit.subscribe(postId: 'p', userId: 'u', userName: 'Alice');

  group('subscribe', () {
    blocTest<LikeButtonCubit, LikeButtonState>(
      'обновляет hasLiked из стрима (false)',
      setUp: () {
        when(
          () => watchHasLiked(any()),
        ).thenAnswer((_) => Stream.value(const Right<Failure, bool>(false)));
      },
      build: buildCubit,
      act: doSubscribe,
      expect: () => [
        isA<LikeButtonState>()
            .having((s) => s.status, 'status', LikeButtonStatus.ready)
            .having((s) => s.hasLiked, 'hasLiked', false)
            .having((s) => s.optimisticHasLiked, 'opt', isNull),
      ],
    );

    blocTest<LikeButtonCubit, LikeButtonState>(
      'обновляет hasLiked из стрима (true)',
      setUp: () {
        when(
          () => watchHasLiked(any()),
        ).thenAnswer((_) => Stream.value(const Right<Failure, bool>(true)));
      },
      build: buildCubit,
      act: doSubscribe,
      expect: () => [
        isA<LikeButtonState>()
            .having((s) => s.status, 'status', LikeButtonStatus.ready)
            .having((s) => s.hasLiked, 'hasLiked', true),
      ],
    );

    blocTest<LikeButtonCubit, LikeButtonState>(
      'Failure из стрима эмитит error',
      setUp: () {
        when(() => watchHasLiked(any())).thenAnswer(
          (_) => Stream.value(
            const Left<Failure, bool>(ServerFailure(message: 'boom')),
          ),
        );
      },
      build: buildCubit,
      act: doSubscribe,
      expect: () => [
        isA<LikeButtonState>()
            .having((s) => s.status, 'status', LikeButtonStatus.error)
            .having((s) => s.errorMessage, 'msg', 'boom'),
      ],
    );

    blocTest<LikeButtonCubit, LikeButtonState>(
      'повторный subscribe c теми же id не пересоздаёт подписку',
      setUp: () {
        when(
          () => watchHasLiked(any()),
        ).thenAnswer((_) => Stream.value(const Right<Failure, bool>(false)));
      },
      build: buildCubit,
      act: (c) async {
        await doSubscribe(c);
        await doSubscribe(c);
      },
      verify: (_) {
        verify(() => watchHasLiked(any())).called(1);
      },
    );
  });

  group('toggle (optimistic UI)', () {
    blocTest<LikeButtonCubit, LikeButtonState>(
      'тап ставит лайк: optimistic +1, потом ready',
      setUp: () {
        when(
          () => watchHasLiked(any()),
        ).thenAnswer((_) => Stream.value(const Right<Failure, bool>(false)));
        when(
          () => likePost(any()),
        ).thenAnswer((_) async => const Right<Failure, void>(null));
      },
      build: buildCubit,
      act: (c) async {
        await doSubscribe(c);
        await Future<void>.delayed(Duration.zero);
        await c.toggle();
      },
      expect: () => [
        // первый emit от стрима
        isA<LikeButtonState>()
            .having((s) => s.status, 'status', LikeButtonStatus.ready)
            .having((s) => s.hasLiked, 'hasLiked', false),
        // оптимистично выставили +1
        isA<LikeButtonState>()
            .having((s) => s.status, 'status', LikeButtonStatus.mutating)
            .having((s) => s.optimisticHasLiked, 'opt', true)
            .having((s) => s.optimisticDelta, 'delta', 1),
        // успех -> ready (optimistic ещё не сброшен, ждём стрим)
        isA<LikeButtonState>()
            .having((s) => s.status, 'status', LikeButtonStatus.ready)
            .having((s) => s.optimisticHasLiked, 'opt', true)
            .having((s) => s.optimisticDelta, 'delta', 1),
      ],
      verify: (_) {
        verify(() => likePost(any())).called(1);
        verifyNever(() => unlikePost(any()));
      },
    );

    blocTest<LikeButtonCubit, LikeButtonState>(
      'тап анлайкает: optimistic -1, потом ready',
      setUp: () {
        when(
          () => watchHasLiked(any()),
        ).thenAnswer((_) => Stream.value(const Right<Failure, bool>(true)));
        when(
          () => unlikePost(any()),
        ).thenAnswer((_) async => const Right<Failure, void>(null));
      },
      build: buildCubit,
      act: (c) async {
        await doSubscribe(c);
        await Future<void>.delayed(Duration.zero);
        await c.toggle();
      },
      expect: () => [
        isA<LikeButtonState>().having((s) => s.hasLiked, 'hasLiked', true),
        isA<LikeButtonState>()
            .having((s) => s.optimisticHasLiked, 'opt', false)
            .having((s) => s.optimisticDelta, 'delta', -1),
        isA<LikeButtonState>().having(
          (s) => s.status,
          'status',
          LikeButtonStatus.ready,
        ),
      ],
      verify: (_) {
        verify(() => unlikePost(any())).called(1);
        verifyNever(() => likePost(any()));
      },
    );

    blocTest<LikeButtonCubit, LikeButtonState>(
      'ошибка лайка откатывает optimistic',
      setUp: () {
        when(
          () => watchHasLiked(any()),
        ).thenAnswer((_) => Stream.value(const Right<Failure, bool>(false)));
        when(() => likePost(any())).thenAnswer(
          (_) async => const Left<Failure, void>(ServerFailure(message: 'no')),
        );
      },
      build: buildCubit,
      act: (c) async {
        await doSubscribe(c);
        await Future<void>.delayed(Duration.zero);
        await c.toggle();
      },
      expect: () => [
        isA<LikeButtonState>().having((s) => s.hasLiked, 'hasLiked', false),
        isA<LikeButtonState>()
            .having((s) => s.optimisticHasLiked, 'opt', true)
            .having((s) => s.optimisticDelta, 'delta', 1),
        isA<LikeButtonState>()
            .having((s) => s.status, 'status', LikeButtonStatus.error)
            .having((s) => s.optimisticHasLiked, 'opt rollback', isNull)
            .having((s) => s.optimisticDelta, 'delta rollback', 0)
            .having((s) => s.errorMessage, 'msg', 'no'),
      ],
    );

    test('стрим, догнавший optimistic, сбрасывает optimisticDelta', () async {
      final controller = StreamController<Either<Failure, bool>>();
      when(() => watchHasLiked(any())).thenAnswer((_) => controller.stream);
      when(
        () => likePost(any()),
      ).thenAnswer((_) async => const Right<Failure, void>(null));

      final cubit = buildCubit();
      await doSubscribe(cubit);
      controller.add(const Right<Failure, bool>(false));
      await Future<void>.delayed(Duration.zero);
      await cubit.toggle();
      // Стрим догоняет наш оптимизм.
      controller.add(const Right<Failure, bool>(true));
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.hasLiked, true);
      expect(cubit.state.optimisticHasLiked, isNull);
      expect(cubit.state.optimisticDelta, 0);
      await controller.close();
      await cubit.close();
    });

    blocTest<LikeButtonCubit, LikeButtonState>(
      'повторный toggle во время mutating игнорируется',
      setUp: () {
        when(
          () => watchHasLiked(any()),
        ).thenAnswer((_) => Stream.value(const Right<Failure, bool>(false)));
        when(() => likePost(any())).thenAnswer((_) async {
          // эмулируем долгий запрос
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return const Right<Failure, void>(null);
        });
      },
      build: buildCubit,
      act: (c) async {
        await doSubscribe(c);
        await Future<void>.delayed(Duration.zero);
        // не ждём — отправляем повторный toggle сразу
        final f1 = c.toggle();
        await c.toggle();
        await f1;
      },
      verify: (_) {
        // Только один реальный вызов likePost, второй проигнорирован.
        verify(() => likePost(any())).called(1);
      },
    );
  });
}
