import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/group.dart';
import '../../domain/usecases/create_group.dart';
import '../../domain/usecases/watch_my_groups.dart';
import '../../domain/usecases/watch_public_groups.dart';

part 'groups_list_event.dart';
part 'groups_list_state.dart';

/// Управляет списочным экраном групп (две вкладки) и формой создания.
///
/// Подписки на «мои» и «публичные» живут параллельно и переоткрываются
/// в `_onSubscribeRequested` только если изменился `userId` — повторный
/// `subscribe` с тем же uid игнорируется.
@injectable
class GroupsListBloc extends Bloc<GroupsListEvent, GroupsListState> {
  GroupsListBloc(
    this._watchMyGroups,
    this._watchPublicGroups,
    this._createGroup,
  ) : super(const GroupsListState.initial()) {
    on<GroupsListSubscribeRequested>(_onSubscribeRequested);
    on<GroupsListCreateRequested>(_onCreateRequested);
    on<GroupsListCreationAcknowledged>(_onCreationAcknowledged);
    on<GroupsListResetRequested>(_onResetRequested);
    on<_GroupsListMyReceived>(_onMyReceived);
    on<_GroupsListPublicReceived>(_onPublicReceived);
  }

  final WatchMyGroups _watchMyGroups;
  final WatchPublicGroups _watchPublicGroups;
  final CreateGroup _createGroup;

  StreamSubscription<Either<Failure, List<Group>>>? _mySub;
  StreamSubscription<Either<Failure, List<Group>>>? _publicSub;
  String? _currentUserId;

  Future<void> _onSubscribeRequested(
    GroupsListSubscribeRequested event,
    Emitter<GroupsListState> emit,
  ) async {
    if (_currentUserId == event.userId && _mySub != null) return;
    _currentUserId = event.userId;

    emit(state.copyWith(status: GroupsListStatus.loading, clearError: true));

    await _mySub?.cancel();
    _mySub = _watchMyGroups(
      event.userId,
    ).listen((result) => add(_GroupsListMyReceived(result)));

    await _publicSub?.cancel();
    _publicSub = _watchPublicGroups(
      const WatchPublicGroupsParams(),
    ).listen((result) => add(_GroupsListPublicReceived(result)));
  }

  void _onMyReceived(
    _GroupsListMyReceived event,
    Emitter<GroupsListState> emit,
  ) {
    event.result.fold(
      (failure) => emit(
        state.copyWith(
          status: GroupsListStatus.error,
          errorMessage: failure.message ?? 'Не удалось загрузить группы',
        ),
      ),
      (groups) => emit(
        state.copyWith(
          status: GroupsListStatus.ready,
          myGroups: groups,
          clearError: true,
        ),
      ),
    );
  }

  void _onPublicReceived(
    _GroupsListPublicReceived event,
    Emitter<GroupsListState> emit,
  ) {
    event.result.fold(
      (failure) => emit(
        state.copyWith(
          status: GroupsListStatus.error,
          errorMessage: failure.message ?? 'Не удалось загрузить витрину',
        ),
      ),
      (groups) => emit(
        state.copyWith(
          status: GroupsListStatus.ready,
          publicGroups: groups,
          clearError: true,
        ),
      ),
    );
  }

  Future<void> _onCreateRequested(
    GroupsListCreateRequested event,
    Emitter<GroupsListState> emit,
  ) async {
    final ownerId = _currentUserId;
    if (ownerId == null) {
      emit(
        state.copyWith(
          status: GroupsListStatus.error,
          errorMessage: 'Профиль ещё не загружен',
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: GroupsListStatus.creating,
        clearError: true,
        clearCreatedId: true,
      ),
    );

    final result = await _createGroup(
      CreateGroupParams(
        ownerId: ownerId,
        name: event.name.trim(),
        description: event.description.trim(),
        isPublic: event.isPublic,
        tags: event.tags,
      ),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: GroupsListStatus.error,
          errorMessage: failure.message ?? 'Не удалось создать группу',
        ),
      ),
      (group) => emit(
        state.copyWith(
          status: GroupsListStatus.created,
          createdGroupId: group.id,
        ),
      ),
    );
  }

  void _onCreationAcknowledged(
    GroupsListCreationAcknowledged event,
    Emitter<GroupsListState> emit,
  ) {
    emit(
      state.copyWith(
        status: GroupsListStatus.ready,
        clearCreatedId: true,
        clearError: true,
      ),
    );
  }

  Future<void> _onResetRequested(
    GroupsListResetRequested event,
    Emitter<GroupsListState> emit,
  ) async {
    await _mySub?.cancel();
    await _publicSub?.cancel();
    _mySub = null;
    _publicSub = null;
    _currentUserId = null;
    emit(const GroupsListState.initial());
  }

  @override
  Future<void> close() async {
    await _mySub?.cancel();
    await _publicSub?.cancel();
    return super.close();
  }
}
