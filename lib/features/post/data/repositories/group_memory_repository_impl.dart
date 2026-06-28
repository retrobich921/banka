import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/utils/typedefs.dart';
import '../../domain/repositories/group_memory_repository.dart';
import '../datasources/group_memory_local_data_source.dart';

/// Реализация [GroupMemoryRepository] через локальное хранилище.
///
/// Оборачивает вызовы [GroupMemoryLocalDataSource] в try-catch,
/// возвращая [CacheFailure] при ошибках.
@LazySingleton(as: GroupMemoryRepository)
class GroupMemoryRepositoryImpl implements GroupMemoryRepository {
  const GroupMemoryRepositoryImpl(this._localDataSource);

  final GroupMemoryLocalDataSource _localDataSource;

  @override
  ResultFuture<String?> getLastSelectedGroup() async {
    try {
      final groupId = await _localDataSource.getLastSelectedGroup();
      return Right(groupId);
    } catch (e, stackTrace) {
      return Left(
        CacheFailure(
          message: 'Failed to get last selected group: $e',
          cause: stackTrace,
        ),
      );
    }
  }

  @override
  ResultFuture<void> saveLastSelectedGroup(String groupId) async {
    try {
      await _localDataSource.saveLastSelectedGroup(groupId);
      return const Right(null);
    } catch (e, stackTrace) {
      return Left(
        CacheFailure(
          message: 'Failed to save last selected group: $e',
          cause: stackTrace,
        ),
      );
    }
  }

  @override
  ResultFuture<void> clearLastSelectedGroup() async {
    try {
      await _localDataSource.clearLastSelectedGroup();
      return const Right(null);
    } catch (e, stackTrace) {
      return Left(
        CacheFailure(
          message: 'Failed to clear last selected group: $e',
          cause: stackTrace,
        ),
      );
    }
  }
}
