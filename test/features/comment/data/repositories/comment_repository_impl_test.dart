import 'package:banka/core/error/exceptions.dart';
import 'package:banka/core/error/failures.dart';
import 'package:banka/features/comment/data/datasources/comment_remote_data_source.dart';
import 'package:banka/features/comment/data/repositories/comment_repository_impl.dart';
import 'package:banka/features/comment/domain/entities/comment.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRemote extends Mock implements CommentRemoteDataSource {}

void main() {
  late _MockRemote remote;
  late CommentRepositoryImpl repo;

  setUp(() {
    remote = _MockRemote();
    repo = CommentRepositoryImpl(remote);
  });

  group('addComment', () {
    test('Right(id) при успешном вызове datasource', () async {
      when(
        () => remote.addComment(
          postId: any(named: 'postId'),
          authorId: any(named: 'authorId'),
          authorName: any(named: 'authorName'),
          authorPhotoUrl: any(named: 'authorPhotoUrl'),
          text: any(named: 'text'),
        ),
      ).thenAnswer((_) async => 'cid-1');

      final r = await repo.addComment(
        postId: 'p',
        authorId: 'u',
        authorName: 'Alice',
        text: 'hi',
      );

      r.fold((_) => fail('expected Right'), (id) => expect(id, 'cid-1'));
    });

    test('ServerException → Left(ServerFailure)', () async {
      when(
        () => remote.addComment(
          postId: any(named: 'postId'),
          authorId: any(named: 'authorId'),
          authorName: any(named: 'authorName'),
          authorPhotoUrl: any(named: 'authorPhotoUrl'),
          text: any(named: 'text'),
        ),
      ).thenThrow(const ServerException(message: 'boom'));

      final r = await repo.addComment(
        postId: 'p',
        authorId: 'u',
        authorName: 'Alice',
        text: 'hi',
      );

      r.fold((l) {
        expect(l, isA<ServerFailure>());
        expect(l.message, 'boom');
      }, (_) => fail('expected Left'));
    });
  });

  group('deleteComment', () {
    test('Right(null) при успешном вызове', () async {
      when(
        () => remote.deleteComment(
          postId: any(named: 'postId'),
          commentId: any(named: 'commentId'),
        ),
      ).thenAnswer((_) async {});

      final r = await repo.deleteComment(postId: 'p', commentId: 'c');
      expect(r.isRight(), true);
    });

    test('ServerException → Left(ServerFailure)', () async {
      when(
        () => remote.deleteComment(
          postId: any(named: 'postId'),
          commentId: any(named: 'commentId'),
        ),
      ).thenThrow(const ServerException(message: 'denied'));

      final r = await repo.deleteComment(postId: 'p', commentId: 'c');
      r.fold((l) => expect(l.message, 'denied'), (_) => fail('expected Left'));
    });
  });

  group('watchComments', () {
    test('пробрасывает список комментариев в Right', () async {
      when(() => remote.watchComments('p')).thenAnswer(
        (_) => Stream.value(const <Comment>[
          Comment(id: 'c1', authorId: 'a', text: 'hi'),
          Comment(id: 'c2', authorId: 'b', text: 'hello'),
        ]),
      );

      final values = await repo.watchComments('p').toList();
      expect(values.length, 1);
      values.first.fold((_) => fail('expected Right'), (comments) {
        expect(comments.length, 2);
        expect(comments.first.id, 'c1');
      });
    });
  });
}
