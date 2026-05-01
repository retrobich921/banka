import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/typedefs.dart';
import '../../domain/entities/group.dart';
import '../../domain/repositories/group_repository.dart';
import '../datasources/group_remote_data_source.dart';

@LazySingleton(as: GroupRepository)
final class GroupRepositoryImpl implements GroupRepository {
  GroupRepositoryImpl(this._remote);

  final GroupRemoteDataSource _remote;

  @override
  ResultFuture<Group> createGroup({
    required String ownerId,
    required String name,
    String description = '',
    bool isPublic = true,
    List<String> tags = const <String>[],
    String? coverUrl,
  }) async {
    try {
      final group = await _remote.createGroup(
        ownerId: ownerId,
        name: name,
        description: description,
        isPublic: isPublic,
        tags: tags,
        coverUrl: coverUrl,
      );
      return Right(group);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, cause: e.cause));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString(), cause: e));
    }
  }

  @override
  ResultFuture<Group?> getGroup(String groupId) async {
    try {
      return Right(await _remote.getGroup(groupId));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, cause: e.cause));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString(), cause: e));
    }
  }

  @override
  ResultStream<Group?> watchGroup(String groupId) async* {
    try {
      await for (final group in _remote.watchGroup(groupId)) {
        yield Right<Failure, Group?>(group);
      }
    } on ServerException catch (e) {
      yield Left<Failure, Group?>(
        ServerFailure(message: e.message, cause: e.cause),
      );
    } catch (e) {
      yield Left<Failure, Group?>(
        ServerFailure(message: e.toString(), cause: e),
      );
    }
  }

  @override
  ResultStream<List<Group>> watchMyGroups(String userId) async* {
    try {
      await for (final groups in _remote.watchMyGroups(userId)) {
        yield Right<Failure, List<Group>>(groups);
      }
    } on ServerException catch (e) {
      yield Left<Failure, List<Group>>(
        ServerFailure(message: e.message, cause: e.cause),
      );
    } catch (e) {
      yield Left<Failure, List<Group>>(
        ServerFailure(message: e.toString(), cause: e),
      );
    }
  }

  @override
  ResultStream<List<Group>> watchPublicGroups({
    int limit = 20,
    String? startAfterId,
  }) async* {
    try {
      await for (final groups in _remote.watchPublicGroups(
        limit: limit,
        startAfterId: startAfterId,
      )) {
        yield Right<Failure, List<Group>>(groups);
      }
    } on ServerException catch (e) {
      yield Left<Failure, List<Group>>(
        ServerFailure(message: e.message, cause: e.cause),
      );
    } catch (e) {
      yield Left<Failure, List<Group>>(
        ServerFailure(message: e.toString(), cause: e),
      );
    }
  }

  @override
  ResultFuture<void> updateGroup({
    required String groupId,
    String? name,
    String? description,
    bool? isPublic,
    String? coverUrl,
    List<String>? tags,
  }) async {
    try {
      await _remote.updateGroup(
        groupId: groupId,
        name: name,
        description: description,
        isPublic: isPublic,
        coverUrl: coverUrl,
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
  ResultFuture<void> deleteGroup(String groupId) async {
    try {
      await _remote.deleteGroup(groupId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, cause: e.cause));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString(), cause: e));
    }
  }

  @override
  ResultFuture<void> joinGroup({
    required String groupId,
    required String userId,
  }) async {
    try {
      await _remote.joinGroup(groupId: groupId, userId: userId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, cause: e.cause));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString(), cause: e));
    }
  }

  @override
  ResultFuture<void> leaveGroup({
    required String groupId,
    required String userId,
  }) async {
    try {
      await _remote.leaveGroup(groupId: groupId, userId: userId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, cause: e.cause));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString(), cause: e));
    }
  }

  @override
  ResultStream<List<GroupMember>> watchGroupMembers(String groupId) async* {
    try {
      await for (final members in _remote.watchGroupMembers(groupId)) {
        yield Right<Failure, List<GroupMember>>(members);
      }
    } on ServerException catch (e) {
      yield Left<Failure, List<GroupMember>>(
        ServerFailure(message: e.message, cause: e.cause),
      );
    } catch (e) {
      yield Left<Failure, List<GroupMember>>(
        ServerFailure(message: e.toString(), cause: e),
      );
    }
  }

  @override
  ResultFuture<GroupMember?> getMembership({
    required String groupId,
    required String userId,
  }) async {
    try {
      final member = await _remote.getMembership(
        groupId: groupId,
        userId: userId,
      );
      return Right(member);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, cause: e.cause));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString(), cause: e));
    }
  }
}
