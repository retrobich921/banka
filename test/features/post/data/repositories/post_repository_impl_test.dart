import 'package:banka/core/error/exceptions.dart';
import 'package:banka/core/error/failures.dart';
import 'package:banka/features/post/data/datasources/post_remote_data_source.dart';
import 'package:banka/features/post/data/repositories/post_repository_impl.dart';
import 'package:banka/features/post/domain/entities/post.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRemote extends Mock implements PostRemoteDataSource {}

void main() {
  late _MockRemote remote;
  late PostRepositoryImpl repository;

  const postId = 'p-1';
  const authorId = 'uid-1';
  final fixturePost = Post(
    id: postId,
    authorId: authorId,
    authorName: 'Albert',
    drinkName: 'Monster Energy',
    photos: const [
      PostPhoto(url: 'https://cdn/x.jpg', thumbUrl: 'https://cdn/x.jpg'),
    ],
    foundDate: DateTime(2025, 5, 1),
    rarity: 7,
    createdAt: DateTime(2025, 5, 1),
    updatedAt: DateTime(2025, 5, 1),
  );

  setUp(() {
    remote = _MockRemote();
    repository = PostRepositoryImpl(remote);
  });

  group('createPost', () {
    test('returns Right(post) on success', () async {
      when(
        () => remote.createPost(
          authorId: any(named: 'authorId'),
          authorName: any(named: 'authorName'),
          authorPhotoUrl: any(named: 'authorPhotoUrl'),
          drinkName: any(named: 'drinkName'),
          groupId: any(named: 'groupId'),
          groupName: any(named: 'groupName'),
          brandId: any(named: 'brandId'),
          brandName: any(named: 'brandName'),
          photos: any(named: 'photos'),
          foundDate: any(named: 'foundDate'),
          rarity: any(named: 'rarity'),
          description: any(named: 'description'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((_) async => fixturePost);

      final result = await repository.createPost(
        authorId: authorId,
        authorName: 'Albert',
        drinkName: 'Monster Energy',
        photos: fixturePost.photos,
        foundDate: fixturePost.foundDate!,
        rarity: 7,
      );

      expect(result, Right<Failure, Post>(fixturePost));
    });

    test('maps ServerException to Left(ServerFailure)', () async {
      when(
        () => remote.createPost(
          authorId: any(named: 'authorId'),
          authorName: any(named: 'authorName'),
          authorPhotoUrl: any(named: 'authorPhotoUrl'),
          drinkName: any(named: 'drinkName'),
          groupId: any(named: 'groupId'),
          groupName: any(named: 'groupName'),
          brandId: any(named: 'brandId'),
          brandName: any(named: 'brandName'),
          photos: any(named: 'photos'),
          foundDate: any(named: 'foundDate'),
          rarity: any(named: 'rarity'),
          description: any(named: 'description'),
          tags: any(named: 'tags'),
        ),
      ).thenThrow(const ServerException(message: 'denied'));

      final result = await repository.createPost(
        authorId: authorId,
        authorName: 'A',
        drinkName: 'D',
        photos: const [],
        foundDate: DateTime(2025, 1, 1),
        rarity: 1,
      );

      expect(result.isLeft(), isTrue);
      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('streams', () {
    test('watchPost wraps each value in Right', () async {
      when(
        () => remote.watchPost(postId),
      ).thenAnswer((_) => Stream.value(fixturePost));

      final emitted = await repository.watchPost(postId).take(1).toList();

      expect(emitted, [Right<Failure, Post?>(fixturePost)]);
    });

    test('watchPost converts errors to Left(ServerFailure)', () async {
      when(
        () => remote.watchPost(postId),
      ).thenAnswer((_) => Stream<Post?>.error(StateError('boom')));

      final emitted = await repository.watchPost(postId).toList();

      expect(emitted.length, 1);
      emitted.first.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test('watchFeed delegates with limit + cursor', () async {
      when(
        () => remote.watchFeed(limit: 5, startAfterId: 'cursor'),
      ).thenAnswer((_) => Stream.value([fixturePost]));

      final emitted = await repository
          .watchFeed(limit: 5, startAfterId: 'cursor')
          .take(1)
          .toList();

      expect(emitted, hasLength(1));
      emitted.first.fold(
        (_) => fail('expected Right'),
        (posts) => expect(posts, [fixturePost]),
      );
    });

    test('watchGroupFeed scopes by groupId', () async {
      when(
        () => remote.watchGroupFeed(
          groupId: 'grp-1',
          limit: 20,
          startAfterId: null,
        ),
      ).thenAnswer((_) => Stream.value([fixturePost]));

      final emitted = await repository
          .watchGroupFeed(groupId: 'grp-1')
          .take(1)
          .toList();
      emitted.first.fold(
        (_) => fail('expected Right'),
        (posts) => expect(posts, [fixturePost]),
      );
    });

    test('watchAuthorFeed scopes by authorId', () async {
      when(
        () => remote.watchAuthorFeed(
          authorId: authorId,
          limit: 20,
          startAfterId: null,
        ),
      ).thenAnswer((_) => Stream.value([fixturePost]));

      final emitted = await repository
          .watchAuthorFeed(authorId: authorId)
          .take(1)
          .toList();
      emitted.first.fold(
        (_) => fail('expected Right'),
        (posts) => expect(posts, [fixturePost]),
      );
    });
  });

  group('updatePost / deletePost', () {
    test('updatePost returns Right(null) on success', () async {
      when(
        () => remote.updatePost(
          postId: any(named: 'postId'),
          drinkName: any(named: 'drinkName'),
          brandId: any(named: 'brandId'),
          brandName: any(named: 'brandName'),
          foundDate: any(named: 'foundDate'),
          rarity: any(named: 'rarity'),
          description: any(named: 'description'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((_) async {});

      final result = await repository.updatePost(postId: postId, rarity: 9);

      expect(result.isRight(), isTrue);
    });

    test('updatePost maps ServerException', () async {
      when(
        () => remote.updatePost(
          postId: any(named: 'postId'),
          drinkName: any(named: 'drinkName'),
          brandId: any(named: 'brandId'),
          brandName: any(named: 'brandName'),
          foundDate: any(named: 'foundDate'),
          rarity: any(named: 'rarity'),
          description: any(named: 'description'),
          tags: any(named: 'tags'),
        ),
      ).thenThrow(const ServerException(message: 'no'));

      final result = await repository.updatePost(postId: postId, rarity: 9);
      expect(result.isLeft(), isTrue);
    });

    test('deletePost returns Right(null) on success', () async {
      when(() => remote.deletePost(postId)).thenAnswer((_) async {});
      final result = await repository.deletePost(postId);
      expect(result.isRight(), isTrue);
    });

    test('deletePost maps ServerException', () async {
      when(
        () => remote.deletePost(postId),
      ).thenThrow(const ServerException(message: 'no'));
      final result = await repository.deletePost(postId);
      expect(result.isLeft(), isTrue);
    });
  });

  group('searchPosts', () {
    test('passes the first ≥2-char token in lowercase to remote', () async {
      when(
        () => remote.searchPosts(
          token: any(named: 'token'),
          rarityMin: any(named: 'rarityMin'),
          rarityMax: any(named: 'rarityMax'),
          brandId: any(named: 'brandId'),
          groupId: any(named: 'groupId'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => [fixturePost]);

      final result = await repository.searchPosts(query: 'A Monster Energy');

      expect(result.isRight(), isTrue);
      verify(
        () => remote.searchPosts(
          token: 'monster',
          rarityMin: null,
          rarityMax: null,
          brandId: null,
          groupId: null,
          limit: 50,
        ),
      ).called(1);
    });

    test('null query → null token (browse + filter mode)', () async {
      when(
        () => remote.searchPosts(
          token: any(named: 'token'),
          rarityMin: any(named: 'rarityMin'),
          rarityMax: any(named: 'rarityMax'),
          brandId: any(named: 'brandId'),
          groupId: any(named: 'groupId'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => [fixturePost]);

      await repository.searchPosts(rarityMin: 5, rarityMax: 9);

      verify(
        () => remote.searchPosts(
          token: null,
          rarityMin: 5,
          rarityMax: 9,
          brandId: null,
          groupId: null,
          limit: 50,
        ),
      ).called(1);
    });

    test('1-char query is not treated as a token', () async {
      when(
        () => remote.searchPosts(
          token: any(named: 'token'),
          rarityMin: any(named: 'rarityMin'),
          rarityMax: any(named: 'rarityMax'),
          brandId: any(named: 'brandId'),
          groupId: any(named: 'groupId'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => const <Post>[]);

      await repository.searchPosts(query: 'a');

      verify(
        () => remote.searchPosts(
          token: null,
          rarityMin: null,
          rarityMax: null,
          brandId: null,
          groupId: null,
          limit: 50,
        ),
      ).called(1);
    });

    test('maps ServerException to Left(ServerFailure)', () async {
      when(
        () => remote.searchPosts(
          token: any(named: 'token'),
          rarityMin: any(named: 'rarityMin'),
          rarityMax: any(named: 'rarityMax'),
          brandId: any(named: 'brandId'),
          groupId: any(named: 'groupId'),
          limit: any(named: 'limit'),
        ),
      ).thenThrow(const ServerException(message: 'denied'));

      final result = await repository.searchPosts(query: 'monster');

      expect(result.isLeft(), isTrue);
      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });
}
