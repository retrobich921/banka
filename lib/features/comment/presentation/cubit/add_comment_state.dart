part of 'add_comment_cubit.dart';

enum AddCommentStatus { idle, submitting, success, error }

final class AddCommentState extends Equatable {
  const AddCommentState({
    this.status = AddCommentStatus.idle,
    this.text = '',
    this.errorMessage,
  });

  const AddCommentState.initial() : this();

  final AddCommentStatus status;
  final String text;
  final String? errorMessage;

  /// Текст после `trim`. Используется для проверки «есть что отправлять».
  String get trimmedText => text.trim();

  /// Кнопка «Отправить» активна, если есть непустой текст и нет
  /// активного запроса.
  bool get canSubmit =>
      status != AddCommentStatus.submitting && trimmedText.isNotEmpty;

  bool get isSubmitting => status == AddCommentStatus.submitting;

  AddCommentState copyWith({
    AddCommentStatus? status,
    String? text,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AddCommentState(
      status: status ?? this.status,
      text: text ?? this.text,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, text, errorMessage];
}
