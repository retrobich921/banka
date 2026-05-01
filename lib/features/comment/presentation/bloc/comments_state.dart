part of 'comments_bloc.dart';

enum CommentsStatus { initial, loading, ready, error }

final class CommentsState extends Equatable {
  const CommentsState({
    this.status = CommentsStatus.initial,
    this.postId,
    this.comments = const [],
    this.errorMessage,
  });

  const CommentsState.initial() : this();

  final CommentsStatus status;
  final String? postId;
  final List<Comment> comments;
  final String? errorMessage;

  bool get isLoading => status == CommentsStatus.loading;
  bool get isReady => status == CommentsStatus.ready;
  bool get hasError => status == CommentsStatus.error;
  bool get isEmpty => isReady && comments.isEmpty;

  CommentsState copyWith({
    CommentsStatus? status,
    String? postId,
    List<Comment>? comments,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CommentsState(
      status: status ?? this.status,
      postId: postId ?? this.postId,
      comments: comments ?? this.comments,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, postId, comments, errorMessage];
}
