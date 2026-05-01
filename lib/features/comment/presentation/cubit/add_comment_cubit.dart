import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/usecases/add_comment.dart';

part 'add_comment_state.dart';

/// Cubit формы отправки комментария.
///
/// Хранит только текст инпута и статус запроса. Реальная лента
/// комментариев живёт в `CommentsBloc` — она отображает new comment
/// сразу после `add` через стрим Firestore.
@injectable
class AddCommentCubit extends Cubit<AddCommentState> {
  AddCommentCubit(this._addComment) : super(const AddCommentState.initial());

  final AddComment _addComment;

  /// Максимальная длина комментария — должна совпадать с правилами
  /// Firestore (`text.size() <= 2000`).
  static const int maxLength = 2000;

  void textChanged(String value) {
    final trimmed = value.length > maxLength
        ? value.substring(0, maxLength)
        : value;
    emit(state.copyWith(text: trimmed, clearError: true));
  }

  /// Отправить комментарий. Возвращает `true`, если запрос завершился
  /// успехом (UI может очистить инпут / закрыть клавиатуру).
  Future<bool> submit({
    required String postId,
    required String authorId,
    required String authorName,
    String? authorPhotoUrl,
  }) async {
    if (!state.canSubmit) return false;

    final text = state.trimmedText;
    emit(state.copyWith(status: AddCommentStatus.submitting, clearError: true));

    final result = await _addComment(
      AddCommentParams(
        postId: postId,
        authorId: authorId,
        authorName: authorName,
        authorPhotoUrl: authorPhotoUrl,
        text: text,
      ),
    );

    return result.fold(
      (failure) {
        emit(
          state.copyWith(
            status: AddCommentStatus.error,
            errorMessage: failure.message ?? 'Не удалось отправить комментарий',
          ),
        );
        return false;
      },
      (_) {
        emit(const AddCommentState(status: AddCommentStatus.success));
        return true;
      },
    );
  }

  /// Сброс ошибки/успеха после показа SnackBar.
  void acknowledged() {
    emit(state.copyWith(status: AddCommentStatus.idle, clearError: true));
  }
}
