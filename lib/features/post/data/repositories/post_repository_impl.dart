import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/typedefs.dart';
import '../../domain/entities/post.dart';
import '../../domain/repositories/post_repository.dart';
import '../datasources/post_remote_data_source.dart';

@LazySingleton(as: PostRepository)
final class PostRepositoryImpl implements PostRepository {
  PostRepositoryImpl(this._remote);

  final PostRemoteDataSource _remote;

  @override
  ResultFuture<Post> createPost({
    required String authorId,
    required String authorName,
    String? authorPhotoUrl,
    required String drinkName,
    String? groupId,
    String? groupName,
    String? brandId,
    String? brandName,
    required List<PostPhoto> photos,
    required DateTime foundDate,
    required int rarity,
    String description = '',
    List<String> tags = const <String>[],
  }) async {
    try {
      final post = await _remote.createPost(
        authorId: authorId,
        authorName: authorName,
        authorPhotoUrl: authorPhotoUrl,
        drinkName: drinkName,
        groupId: groupId,
        groupName: groupName,
        brandId: brandId,
        brandName: brandName,
        photos: photos,
        foundDate: foundDate,
        rarity: rarity,
        description: description,
        tags: tags,
      );
      return Right(post);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, cause: e.cause));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString(), cause: e));
    }
  }

  @override
  ResultFuture<Post?> getPost(String postId) async {
    try {
      return Right(await _remote.getPost(postId));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, cause: e.cause));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString(), cause: e));
    }
  }

  @override
  ResultStream<Post?> watchPost(String postId) async* {
    try {
      await for (final post in _remote.watchPost(postId)) {
        yield Right<Failure, Post?>(post);
      }
    } on ServerException catch (e) {
      yield Left<Failure, Post?>(
        ServerFailure(message: e.message, cause: e.cause),
      );
    } catch (e) {
      yield Left<Failure, Post?>(
        ServerFailure(message: e.toString(), cause: e),
      );
    }
  }

  @override
  ResultStream<List<Post>> watchFeed({int limit = 20, String? startAfterId}) =>
      _wrapListStream(
        _remote.watchFeed(limit: limit, startAfterId: startAfterId),
      );

  @override
  ResultStream<List<Post>> watchGroupFeed({
    required String groupId,
    int limit = 20,
    String? startAfterId,
  }) => _wrapListStream(
    _remote.watchGroupFeed(
      groupId: groupId,
      limit: limit,
      startAfterId: startAfterId,
    ),
  );

  @override
  ResultStream<List<Post>> watchAuthorFeed({
    required String authorId,
    int limit = 20,
    String? startAfterId,
  }) => _wrapListStream(
    _remote.watchAuthorFeed(
      authorId: authorId,
      limit: limit,
      startAfterId: startAfterId,
    ),
  );

  @override
  ResultFuture<void> updatePost({
    required String postId,
    String? drinkName,
    String? brandId,
    String? brandName,
    DateTime? foundDate,
    int? rarity,
    String? description,
    List<String>? tags,
  }) async {
    try {
      await _remote.updatePost(
        postId: postId,
        drinkName: drinkName,
        brandId: brandId,
        brandName: brandName,
        foundDate: foundDate,
        rarity: rarity,
        description: description,
        tags: tags,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, cause: e.cause));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString(), cause: e));
    }
  }

  @override
  ResultFuture<void> deletePost(String postId) async {
    try {
      await _remote.deletePost(postId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, cause: e.cause));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString(), cause: e));
    }
  }

  @override
  ResultFuture<List<Post>> searchPosts({
    String? query,
    int? rarityMin,
    int? rarityMax,
    String? brandId,
    String? groupId,
    int limit = 50,
  }) async {
    try {
      final token = _firstToken(query);
      final posts = await _remote.searchPosts(
        token: token,
        rarityMin: rarityMin,
        rarityMax: rarityMax,
        brandId: brandId,
        groupId: groupId,
        limit: limit,
      );
      return Right(posts);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, cause: e.cause));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString(), cause: e));
    }
  }

  /// Берём первый «значимый» (≥ 2 символов) токен запроса. Так
  /// `searchKeywords arrayContains` будет надёжно совпадать с тем, что
  /// мы пишем в `PostDto.buildSearchKeywords` при создании поста.
  static String? _firstToken(String? raw) {
    if (raw == null) return null;
    for (final word in raw.toLowerCase().split(RegExp(r'\s+'))) {
      final cleaned = word.replaceAll(RegExp(r'[^a-zа-я0-9]'), '');
      if (cleaned.length >= 2) return cleaned;
    }
    return null;
  }

  Stream<Either<Failure, List<Post>>> _wrapListStream(
    Stream<List<Post>> source,
  ) async* {
    try {
      await for (final posts in source) {
        yield Right<Failure, List<Post>>(posts);
      }
    } on ServerException catch (e) {
      yield Left<Failure, List<Post>>(
        ServerFailure(message: e.message, cause: e.cause),
      );
    } catch (e) {
      yield Left<Failure, List<Post>>(
        ServerFailure(message: e.toString(), cause: e),
      );
    }
  }
}
