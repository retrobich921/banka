import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/group.dart';
import '../../domain/usecases/delete_group.dart';
import '../../domain/usecases/join_group.dart';
import '../../domain/usecases/leave_group.dart';
import '../../domain/usecases/watch_group.dart';
import '../../domain/usecases/watch_group_members.dart';

part 'group_detail_event.dart';
part 'group_detail_state.dart';

/// Управляет экраном конкретной группы: real-time подписки на сам документ
/// и подколлекцию `members`, плюс команды join / leave / delete.
@injectable
class GroupDetailBloc extends Bloc<GroupDetailEvent, GroupDetailState> {
  GroupDetailBloc(
    this._watchGroup,
    this._watchGroupMembers,
    this._joinGroup,
    this._leaveGroup,
    this._deleteGroup,
  ) : super(const GroupDetailState.initial()) {
    on<GroupDetailSubscribeRequested>(_onSubscribeRequested);
    on<GroupDetailJoinRequested>(_onJoinRequested);
    on<GroupDetailLeaveRequested>(_onLeaveRequested);
    on<GroupDetailDeleteRequested>(_onDeleteRequested);
    on<GroupDetailResetRequested>(_onResetRequested);
    on<_GroupDetailGroupReceived>(_onGroupReceived);
    on<_GroupDetailMembersReceived>(_onMembersReceived);
  }

  final WatchGroup _watchGroup;
  final WatchGroupMembers _watchGroupMembers;
  final JoinGroup _joinGroup;
  final LeaveGroup _leaveGroup;
  final DeleteGroup _deleteGroup;

  StreamSubscription<Either<Failure, Group?>>? _groupSub;
  StreamSubscription<Either<Failure, List<GroupMember>>>? _membersSub;
  String? _currentGroupId;

  Future<void> _onSubscribeRequested(
    GroupDetailSubscribeRequested event,
    Emitter<GroupDetailState> emit,
  ) async {
    if (_currentGroupId == event.groupId &&
        state.currentUserId == event.currentUserId &&
        _groupSub != null) {
      return;
    }
    _currentGroupId = event.groupId;

    emit(
      state.copyWith(
        status: GroupDetailStatus.loading,
        currentUserId: event.currentUserId,
        clearError: true,
      ),
    );

    await _groupSub?.cancel();
    _groupSub = _watchGroup(
      event.groupId,
    ).listen((result) => add(_GroupDetailGroupReceived(result)));

    await _membersSub?.cancel();
    _membersSub = _watchGroupMembers(
      event.groupId,
    ).listen((result) => add(_GroupDetailMembersReceived(result)));
  }

  void _onGroupReceived(
    _GroupDetailGroupReceived event,
    Emitter<GroupDetailState> emit,
  ) {
    event.result.fold(
      (failure) => emit(
        state.copyWith(
          status: GroupDetailStatus.error,
          errorMessage: failure.message ?? 'Не удалось загрузить группу',
        ),
      ),
      (group) {
        if (group == null) {
          emit(state.copyWith(status: GroupDetailStatus.notFound));
        } else {
          emit(
            state.copyWith(
              status: GroupDetailStatus.ready,
              group: group,
              clearError: true,
            ),
          );
        }
      },
    );
  }

  void _onMembersReceived(
    _GroupDetailMembersReceived event,
    Emitter<GroupDetailState> emit,
  ) {
    event.result.fold(
      (failure) => emit(
        state.copyWith(
          status: GroupDetailStatus.error,
          errorMessage: failure.message ?? 'Не удалось загрузить участников',
        ),
      ),
      (members) => emit(state.copyWith(members: members, clearError: true)),
    );
  }

  Future<void> _onJoinRequested(
    GroupDetailJoinRequested event,
    Emitter<GroupDetailState> emit,
  ) async {
    final groupId = _currentGroupId;
    final userId = state.currentUserId;
    if (groupId == null || userId == null) return;

    emit(state.copyWith(status: GroupDetailStatus.mutating, clearError: true));

    final result = await _joinGroup(
      GroupMembershipParams(groupId: groupId, userId: userId),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: GroupDetailStatus.error,
          errorMessage: failure.message ?? 'Не удалось вступить в группу',
        ),
      ),
      (_) => emit(state.copyWith(status: GroupDetailStatus.ready)),
    );
  }

  Future<void> _onLeaveRequested(
    GroupDetailLeaveRequested event,
    Emitter<GroupDetailState> emit,
  ) async {
    final groupId = _currentGroupId;
    final userId = state.currentUserId;
    if (groupId == null || userId == null) return;

    emit(state.copyWith(status: GroupDetailStatus.mutating, clearError: true));

    final result = await _leaveGroup(
      GroupMembershipParams(groupId: groupId, userId: userId),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: GroupDetailStatus.error,
          errorMessage: failure.message ?? 'Не удалось выйти из группы',
        ),
      ),
      (_) => emit(state.copyWith(status: GroupDetailStatus.ready)),
    );
  }

  Future<void> _onDeleteRequested(
    GroupDetailDeleteRequested event,
    Emitter<GroupDetailState> emit,
  ) async {
    final groupId = _currentGroupId;
    if (groupId == null) return;

    emit(state.copyWith(status: GroupDetailStatus.mutating, clearError: true));

    final result = await _deleteGroup(groupId);

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: GroupDetailStatus.error,
          errorMessage: failure.message ?? 'Не удалось удалить группу',
        ),
      ),
      (_) => emit(state.copyWith(status: GroupDetailStatus.deleted)),
    );
  }

  Future<void> _onResetRequested(
    GroupDetailResetRequested event,
    Emitter<GroupDetailState> emit,
  ) async {
    await _groupSub?.cancel();
    await _membersSub?.cancel();
    _groupSub = null;
    _membersSub = null;
    _currentGroupId = null;
    emit(const GroupDetailState.initial());
  }

  @override
  Future<void> close() async {
    await _groupSub?.cancel();
    await _membersSub?.cancel();
    return super.close();
  }
}
