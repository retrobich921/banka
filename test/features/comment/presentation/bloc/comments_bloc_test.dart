import 'package:banka/core/error/failures.dart';
import 'package:banka/features/comment/domain/entities/comment.dart';
import 'package:banka/features/comment/domain/usecases/watch_comments.dart';
import 'package:banka/features/comment/presentation/bloc/comments_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWatchComments extends Mock implements WatchComments {}

void main() {
  late _MockWatchComments watchComments;

  setUp(() {
    watchComments = _MockWatchComments();
  });

  CommentsBloc buildBloc() => CommentsBloc(watchComments);

  group('CommentsSubscribeRequested', () {
    blocTest<CommentsBloc, CommentsState>(
      'loading → ready при успешном стриме',
      setUp: () {
        when(() => watchComments('p1')).thenAnswer(
          (_) => Stream.value(
            const Right<Failure, List<Comment>>([
              Comment(id: 'c1', authorId: 'a', text: 'hi'),
              Comment(id: 'c2', authorId: 'b', text: 'hello'),
            ]),
          ),
        );
      },
      build: buildBloc,
      act: (b) => b.add(const CommentsSubscribeRequested('p1')),
      expect: () => [
        isA<CommentsState>().having(
          (s) => s.status,
          'status',
          CommentsStatus.loading,
        ),
        isA<CommentsState>()
            .having((s) => s.status, 'status', CommentsStatus.ready)
            .having((s) => s.comments.length, 'count', 2)
            .having((s) => s.comments.first.id, 'first', 'c1'),
      ],
    );

    blocTest<CommentsBloc, CommentsState>(
      'Failure эмитит error',
      setUp: () {
        when(() => watchComments('p1')).thenAnswer(
          (_) => Stream.value(
            const Left<Failure, List<Comment>>(ServerFailure(message: 'boom')),
          ),
        );
      },
      build: buildBloc,
      act: (b) => b.add(const CommentsSubscribeRequested('p1')),
      expect: () => [
        isA<CommentsState>().having(
          (s) => s.status,
          'status',
          CommentsStatus.loading,
        ),
        isA<CommentsState>()
            .having((s) => s.status, 'status', CommentsStatus.error)
            .having((s) => s.errorMessage, 'msg', 'boom'),
      ],
    );

    blocTest<CommentsBloc, CommentsState>(
      'повторный subscribe c тем же id не пересоздаёт подписку',
      setUp: () {
        when(() => watchComments('p1')).thenAnswer(
          (_) => Stream.value(const Right<Failure, List<Comment>>(<Comment>[])),
        );
      },
      build: buildBloc,
      act: (b) async {
        b.add(const CommentsSubscribeRequested('p1'));
        await Future<void>.delayed(Duration.zero);
        b.add(const CommentsSubscribeRequested('p1'));
      },
      verify: (_) {
        verify(() => watchComments('p1')).called(1);
      },
    );

    blocTest<CommentsBloc, CommentsState>(
      'CommentsResetRequested сбрасывает в initial',
      setUp: () {
        when(() => watchComments('p1')).thenAnswer(
          (_) => Stream.value(const Right<Failure, List<Comment>>(<Comment>[])),
        );
      },
      build: buildBloc,
      act: (b) async {
        b.add(const CommentsSubscribeRequested('p1'));
        await Future<void>.delayed(Duration.zero);
        b.add(const CommentsResetRequested());
      },
      skip: 2, // skip loading + ready
      expect: () => [
        isA<CommentsState>().having(
          (s) => s.status,
          'status',
          CommentsStatus.initial,
        ),
      ],
    );
  });
}
