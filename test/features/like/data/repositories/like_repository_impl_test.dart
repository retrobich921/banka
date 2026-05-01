import 'package:banka/core/error/exceptions.dart';
import 'package:banka/core/error/failures.dart';
import 'package:banka/features/like/data/datasources/like_remote_data_source.dart';
import 'package:banka/features/like/data/repositories/like_repository_impl.dart';
import 'package:banka/features/like/domain/entities/like.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRemote extends Mock implements LikeRemoteDataSource {}

void main() {
  late _MockRemote remote;
  late LikeRepositoryImpl repo;

  setUp(() {
    remote = _MockRemote();
    repo = LikeRepositoryImpl(remote);
  });

  group('likePost', () {
    test('Right(null) при успешном вызове datasource', () async {
      when(
        () => remote.likePost(
          postId: any(named: 'postId'),
          userId: any(named: 'userId'),
          userName: any(named: 'userName'),
          userPhotoUrl: any(named: 'userPhotoUrl'),
        ),
      ).thenAnswer((_) async {});

      final r = await repo.likePost(
        postId: 'p',
        userId: 'u',
        userName: 'Alice',
      );

      expect(r.isRight(), true);
    });

    test('ServerException → Left(ServerFailure)', () async {
      when(
        () => remote.likePost(
          postId: any(named: 'postId'),
          userId: any(named: 'userId'),
          userName: any(named: 'userName'),
          userPhotoUrl: any(named: 'userPhotoUrl'),
        ),
      ).thenThrow(const ServerException(message: 'boom'));

      final r = await repo.likePost(
        postId: 'p',
        userId: 'u',
        userName: 'Alice',
      );

      r.fold((l) {
        expect(l, isA<ServerFailure>());
        expect(l.message, 'boom');
      }, (_) => fail('expected Left'));
    });
  });

  group('unlikePost', () {
    test('Right(null) при успешном вызове', () async {
      when(
        () => remote.unlikePost(
          postId: any(named: 'postId'),
          userId: any(named: 'userId'),
        ),
      ).thenAnswer((_) async {});

      final r = await repo.unlikePost(postId: 'p', userId: 'u');
      expect(r.isRight(), true);
    });
  });

  group('watchHasLiked', () {
    test('пробрасывает значения из стрима в Right', () async {
      when(
        () => remote.watchHasLiked(
          postId: any(named: 'postId'),
          userId: any(named: 'userId'),
        ),
      ).thenAnswer((_) => Stream.fromIterable([false, true]));

      final values = await repo
          .watchHasLiked(postId: 'p', userId: 'u')
          .toList();
      expect(values.length, 2);
      expect(values[0].getOrElse(() => false), false);
      expect(values[1].getOrElse(() => false), true);
    });
  });

  group('watchLikers', () {
    test('пробрасывает список лайков в Right', () async {
      when(() => remote.watchLikers('p')).thenAnswer(
        (_) => Stream.value(const <Like>[Like(userId: 'a', userName: 'Alice')]),
      );

      final values = await repo.watchLikers('p').toList();
      expect(values.length, 1);
      values.first.fold((_) => fail('expected Right'), (likes) {
        expect(likes.length, 1);
        expect(likes.first.userId, 'a');
      });
    });
  });
}
