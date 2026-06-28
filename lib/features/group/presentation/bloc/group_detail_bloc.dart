import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/group.dart';
import '../../domain/usecases/delete_group.dart';
import '../../domain/usecases/get_join_request.dart';
import '../../domain/usecases/join_group.dart';
import '../../domain/usecases/leave_group.dart';
import '../../domain/usecases/request_join_group.dart';
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
    this._requestJoinGroup,
    this._leaveGroup,
    this._deleteGroup,
    this._getJoinRequest,
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
  final RequestJoinGroup _requestJoinGroup;
  final LeaveGroup _leaveGroup;
  final DeleteGroup _deleteGroup;
  final GetJoinRequest _getJoinRequest;

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
        currentUserDisplayName: event.currentUserDisplayName,
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
  ) async {
    await event.result.fold(
      (failure) async => emit(
        state.copyWith(
          status: GroupDetailStatus.error,
          errorMessage: failure.message ?? 'Не удалось загрузить группу',
        ),
      ),
      (group) async {
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

          // Загружаем статус запроса на вступление, если пользователь не участник
          final userId = state.currentUserId;
          if (userId != null && !group.membersUids.contains(userId)) {
            final requestResult = await _getJoinRequest(
              groupId: group.id,
              userId: userId,
            );
            requestResult.fold(
              (_) {}, // Игнорируем ошибку
              (request) => emit(state.copyWith(joinRequest: request)),
            );
          } else {
            // Если пользователь уже участник, очищаем запрос
            emit(state.copyWith(clearJoinRequest: true));
          }
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
    final displayName = state.currentUserDisplayName;
    final group = state.group;
    if (groupId == null || userId == null || group == null) return;

    emit(state.copyWith(status: GroupDetailStatus.mutating, clearError: true));

    final params = GroupMembershipParams(
      groupId: groupId,
      userId: userId,
      displayName:
          displayName ?? userId, // Fallback to userId if displayName is null
    );

    // Если группа закрытая, создаём запрос на вступление
    // Если публичная, сразу добавляем в участники
    final result = group.isPublic
        ? await _joinGroup(params)
        : await _requestJoinGroup(params);

    await result.fold(
      (failure) async => emit(
        state.copyWith(
          status: GroupDetailStatus.error,
          errorMessage:
              failure.message ??
              (group.isPublic
                  ? 'Не удалось вступить в группу'
                  : 'Не удалось отправить запрос'),
        ),
      ),
      (_) async {
        emit(state.copyWith(status: GroupDetailStatus.ready));

        // Для закрытых групп загружаем статус запроса
        if (!group.isPublic) {
          final requestResult = await _getJoinRequest(
            groupId: groupId,
            userId: userId,
          );
          requestResult.fold(
            (_) {}, // Игнорируем ошибку
            (request) => emit(state.copyWith(joinRequest: request)),
          );
        }
      },
    );
  }

  Future<void> _onLeaveRequested(
    GroupDetailLeaveRequested event,
    Emitter<GroupDetailState> emit,
  ) async {
    final groupId = _currentGroupId;
    final userId = state.currentUserId;
    final displayName = state.currentUserDisplayName;
    if (groupId == null || userId == null) return;

    emit(state.copyWith(status: GroupDetailStatus.mutating, clearError: true));

    final result = await _leaveGroup(
      GroupMembershipParams(
        groupId: groupId,
        userId: userId,
        displayName: displayName ?? '',
      ),
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
