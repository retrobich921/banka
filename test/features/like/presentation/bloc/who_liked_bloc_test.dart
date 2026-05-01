import 'package:banka/core/error/failures.dart';
import 'package:banka/features/like/domain/entities/like.dart';
import 'package:banka/features/like/domain/usecases/watch_likers.dart';
import 'package:banka/features/like/presentation/bloc/who_liked_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWatchLikers extends Mock implements WatchLikers {}

void main() {
  late _MockWatchLikers watchLikers;

  setUp(() {
    watchLikers = _MockWatchLikers();
  });

  WhoLikedBloc buildBloc() => WhoLikedBloc(watchLikers);

  group('WhoLikedSubscribeRequested', () {
    blocTest<WhoLikedBloc, WhoLikedState>(
      'loading → ready при успешном стриме',
      setUp: () {
        when(() => watchLikers('p1')).thenAnswer(
          (_) => Stream.value(
            const Right<Failure, List<Like>>([
              Like(userId: 'a', userName: 'Alice'),
              Like(userId: 'b', userName: 'Bob'),
            ]),
          ),
        );
      },
      build: buildBloc,
      act: (b) => b.add(const WhoLikedSubscribeRequested('p1')),
      expect: () => [
        isA<WhoLikedState>().having(
          (s) => s.status,
          'status',
          WhoLikedStatus.loading,
        ),
        isA<WhoLikedState>()
            .having((s) => s.status, 'status', WhoLikedStatus.ready)
            .having((s) => s.likes.length, 'count', 2)
            .having((s) => s.likes.first.userId, 'first', 'a'),
      ],
    );

    blocTest<WhoLikedBloc, WhoLikedState>(
      'Failure эмитит error',
      setUp: () {
        when(() => watchLikers('p1')).thenAnswer(
          (_) => Stream.value(
            const Left<Failure, List<Like>>(ServerFailure(message: 'boom')),
          ),
        );
      },
      build: buildBloc,
      act: (b) => b.add(const WhoLikedSubscribeRequested('p1')),
      expect: () => [
        isA<WhoLikedState>().having(
          (s) => s.status,
          'status',
          WhoLikedStatus.loading,
        ),
        isA<WhoLikedState>()
            .having((s) => s.status, 'status', WhoLikedStatus.error)
            .having((s) => s.errorMessage, 'msg', 'boom'),
      ],
    );

    blocTest<WhoLikedBloc, WhoLikedState>(
      'повторный subscribe с тем же id не пересоздаёт подписку',
      setUp: () {
        when(() => watchLikers('p1')).thenAnswer(
          (_) => Stream.value(const Right<Failure, List<Like>>(<Like>[])),
        );
      },
      build: buildBloc,
      act: (b) async {
        b.add(const WhoLikedSubscribeRequested('p1'));
        await Future<void>.delayed(Duration.zero);
        b.add(const WhoLikedSubscribeRequested('p1'));
      },
      verify: (_) {
        verify(() => watchLikers('p1')).called(1);
      },
    );
  });
}
