import 'package:banka/core/error/failures.dart';
import 'package:banka/features/post/domain/entities/post.dart';
import 'package:banka/features/post/domain/usecases/watch_post.dart';
import 'package:banka/features/post/presentation/bloc/post_detail_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWatchPost extends Mock implements WatchPost {}

void main() {
  late _MockWatchPost watchPost;

  setUp(() {
    watchPost = _MockWatchPost();
  });

  PostDetailBloc buildBloc() => PostDetailBloc(watchPost);

  group('PostDetailSubscribeRequested', () {
    blocTest<PostDetailBloc, PostDetailState>(
      'loading → ready при успешном посте',
      setUp: () {
        when(() => watchPost('p1')).thenAnswer(
          (_) => Stream.value(
            const Right<Failure, Post?>(
              Post(id: 'p1', authorId: 'a', drinkName: 'Red Bull'),
            ),
          ),
        );
      },
      build: buildBloc,
      act: (b) => b.add(const PostDetailSubscribeRequested('p1')),
      expect: () => [
        isA<PostDetailState>().having(
          (s) => s.status,
          'status',
          PostDetailStatus.loading,
        ),
        isA<PostDetailState>()
            .having((s) => s.status, 'status', PostDetailStatus.ready)
            .having((s) => s.post?.id, 'post.id', 'p1')
            .having((s) => s.post?.drinkName, 'drinkName', 'Red Bull'),
      ],
    );

    blocTest<PostDetailBloc, PostDetailState>(
      'null из стрима → notFound',
      setUp: () {
        when(
          () => watchPost('missing'),
        ).thenAnswer((_) => Stream.value(const Right<Failure, Post?>(null)));
      },
      build: buildBloc,
      act: (b) => b.add(const PostDetailSubscribeRequested('missing')),
      expect: () => [
        isA<PostDetailState>().having(
          (s) => s.status,
          'status',
          PostDetailStatus.loading,
        ),
        isA<PostDetailState>()
            .having((s) => s.status, 'status', PostDetailStatus.notFound)
            .having((s) => s.post, 'post', isNull),
      ],
    );

    blocTest<PostDetailBloc, PostDetailState>(
      'Failure → error с сообщением',
      setUp: () {
        when(() => watchPost('p1')).thenAnswer(
          (_) => Stream.value(
            const Left<Failure, Post?>(ServerFailure(message: 'oops')),
          ),
        );
      },
      build: buildBloc,
      act: (b) => b.add(const PostDetailSubscribeRequested('p1')),
      expect: () => [
        isA<PostDetailState>().having(
          (s) => s.status,
          'status',
          PostDetailStatus.loading,
        ),
        isA<PostDetailState>()
            .having((s) => s.status, 'status', PostDetailStatus.error)
            .having((s) => s.errorMessage, 'msg', 'oops'),
      ],
    );

    blocTest<PostDetailBloc, PostDetailState>(
      'повторный subscribe с тем же id не пересоздаёт подписку',
      setUp: () {
        when(() => watchPost('p1')).thenAnswer(
          (_) => Stream.value(
            const Right<Failure, Post?>(
              Post(id: 'p1', authorId: 'a', drinkName: 'd'),
            ),
          ),
        );
      },
      build: buildBloc,
      act: (b) async {
        b.add(const PostDetailSubscribeRequested('p1'));
        await Future<void>.delayed(Duration.zero);
        b.add(const PostDetailSubscribeRequested('p1'));
      },
      verify: (_) {
        verify(() => watchPost('p1')).called(1);
      },
    );
  });
}
