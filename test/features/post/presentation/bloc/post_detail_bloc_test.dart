import 'package:banka/core/error/failures.dart';
import 'package:banka/features/post/domain/entities/post.dart';
import 'package:banka/features/post/domain/usecases/delete_post.dart';
import 'package:banka/features/post/domain/usecases/set_post_archived.dart';
import 'package:banka/features/post/domain/usecases/watch_post.dart';
import 'package:banka/features/post/presentation/bloc/post_detail_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWatchPost extends Mock implements WatchPost {}

class _MockDeletePost extends Mock implements DeletePost {}

class _MockSetPostArchived extends Mock implements SetPostArchived {}

void main() {
  late _MockWatchPost watchPost;
  late _MockDeletePost deletePost;
  late _MockSetPostArchived setPostArchived;

  setUp(() {
    watchPost = _MockWatchPost();
    deletePost = _MockDeletePost();
    setPostArchived = _MockSetPostArchived();
  });

  PostDetailBloc buildBloc() =>
      PostDetailBloc(watchPost, deletePost, setPostArchived);

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

  group('PostDetailDeleteRequested', () {
    const post = Post(id: 'p1', authorId: 'a', drinkName: 'Red Bull');

    blocTest<PostDetailBloc, PostDetailState>(
      'deleting → deleted при успехе',
      setUp: () {
        when(
          () => watchPost('p1'),
        ).thenAnswer((_) => Stream.value(const Right<Failure, Post?>(post)));
        when(() => deletePost('p1')).thenAnswer((_) async => const Right(null));
      },
      build: buildBloc,
      act: (b) async {
        b.add(const PostDetailSubscribeRequested('p1'));
        await Future<void>.delayed(Duration.zero);
        b.add(const PostDetailDeleteRequested());
      },
      skip: 2, // loading, ready
      expect: () => [
        isA<PostDetailState>().having(
          (s) => s.status,
          'status',
          PostDetailStatus.deleting,
        ),
        isA<PostDetailState>().having(
          (s) => s.status,
          'status',
          PostDetailStatus.deleted,
        ),
      ],
    );

    blocTest<PostDetailBloc, PostDetailState>(
      'deleting → error при Failure, пост остаётся в state',
      setUp: () {
        when(
          () => watchPost('p1'),
        ).thenAnswer((_) => Stream.value(const Right<Failure, Post?>(post)));
        when(() => deletePost('p1')).thenAnswer(
          (_) async => const Left(ServerFailure(message: 'нет прав')),
        );
      },
      build: buildBloc,
      act: (b) async {
        b.add(const PostDetailSubscribeRequested('p1'));
        await Future<void>.delayed(Duration.zero);
        b.add(const PostDetailDeleteRequested());
      },
      skip: 2, // loading, ready
      expect: () => [
        isA<PostDetailState>().having(
          (s) => s.status,
          'status',
          PostDetailStatus.deleting,
        ),
        isA<PostDetailState>()
            .having((s) => s.status, 'status', PostDetailStatus.error)
            .having((s) => s.errorMessage, 'msg', 'нет прав')
            .having((s) => s.post?.id, 'post.id', 'p1'),
        // Возобновлённая подписка снова приносит пост → ready.
        isA<PostDetailState>().having(
          (s) => s.status,
          'status',
          PostDetailStatus.ready,
        ),
      ],
    );

    blocTest<PostDetailBloc, PostDetailState>(
      'без подписки (нет postId) — ничего не делает',
      build: buildBloc,
      act: (b) => b.add(const PostDetailDeleteRequested()),
      expect: () => const <PostDetailState>[],
      verify: (_) => verifyNever(() => deletePost(any())),
    );
  });

  group('PostDetailArchiveToggleRequested', () {
    const post = Post(id: 'p1', authorId: 'a', drinkName: 'Red Bull');

    setUp(() {
      registerFallbackValue(
        const SetPostArchivedParams(postId: '', archived: true),
      );
    });

    blocTest<PostDetailBloc, PostDetailState>(
      'успех — только вызов usecase, состояние обновит стрим',
      setUp: () {
        when(
          () => watchPost('p1'),
        ).thenAnswer((_) => Stream.value(const Right<Failure, Post?>(post)));
        when(
          () => setPostArchived(any()),
        ).thenAnswer((_) async => const Right(null));
      },
      build: buildBloc,
      act: (b) async {
        b.add(const PostDetailSubscribeRequested('p1'));
        await Future<void>.delayed(Duration.zero);
        b.add(const PostDetailArchiveToggleRequested(archived: true));
      },
      skip: 2, // loading, ready
      expect: () => const <PostDetailState>[],
      verify: (_) => verify(
        () => setPostArchived(
          const SetPostArchivedParams(postId: 'p1', archived: true),
        ),
      ).called(1),
    );

    blocTest<PostDetailBloc, PostDetailState>(
      'ошибка — emit error с сообщением',
      setUp: () {
        when(
          () => watchPost('p1'),
        ).thenAnswer((_) => Stream.value(const Right<Failure, Post?>(post)));
        when(() => setPostArchived(any())).thenAnswer(
          (_) async => const Left(ServerFailure(message: 'нет сети')),
        );
      },
      build: buildBloc,
      act: (b) async {
        b.add(const PostDetailSubscribeRequested('p1'));
        await Future<void>.delayed(Duration.zero);
        b.add(const PostDetailArchiveToggleRequested(archived: true));
      },
      skip: 2, // loading, ready
      expect: () => [
        isA<PostDetailState>()
            .having((s) => s.status, 'status', PostDetailStatus.error)
            .having((s) => s.errorMessage, 'msg', 'нет сети'),
      ],
    );
  });
}
