part of 'groups_list_bloc.dart';

sealed class GroupsListEvent extends Equatable {
  const GroupsListEvent();

  @override
  List<Object?> get props => const [];
}

/// Запустить два real-time стрима для текущего пользователя — «мои группы»
/// и витрина публичных. Идемпотентно: повтор с тем же `userId` ничего
/// не делает.
final class GroupsListSubscribeRequested extends GroupsListEvent {
  const GroupsListSubscribeRequested(this.userId);

  final String userId;

  @override
  List<Object?> get props => [userId];
}

/// Создать новую группу. По завершении emit `GroupsListStatus.created`
/// с `createdGroupId`, чтобы UI смог сделать `pushReplacement` на
/// `/groups/:id`.
final class GroupsListCreateRequested extends GroupsListEvent {
  const GroupsListCreateRequested({
    required this.name,
    this.description = '',
    this.isPublic = true,
    this.tags = const <String>[],
  });

  final String name;
  final String description;
  final bool isPublic;
  final List<String> tags;

  @override
  List<Object?> get props => [name, description, isPublic, tags];
}

/// Сбросить хвост `created` после того, как UI обработал переход.
final class GroupsListCreationAcknowledged extends GroupsListEvent {
  const GroupsListCreationAcknowledged();
}

final class GroupsListResetRequested extends GroupsListEvent {
  const GroupsListResetRequested();
}

final class _GroupsListMyReceived extends GroupsListEvent {
  const _GroupsListMyReceived(this.result);

  final Either<Failure, List<Group>> result;

  @override
  List<Object?> get props => [result];
}

final class _GroupsListPublicReceived extends GroupsListEvent {
  const _GroupsListPublicReceived(this.result);

  final Either<Failure, List<Group>> result;

  @override
  List<Object?> get props => [result];
}
