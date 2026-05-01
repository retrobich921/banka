part of 'post_detail_bloc.dart';

enum PostDetailStatus { initial, loading, ready, notFound, error }

final class PostDetailState extends Equatable {
  const PostDetailState({
    this.status = PostDetailStatus.initial,
    this.post,
    this.errorMessage,
  });

  const PostDetailState.initial() : this();

  final PostDetailStatus status;
  final Post? post;
  final String? errorMessage;

  PostDetailState copyWith({
    PostDetailStatus? status,
    Post? post,
    String? errorMessage,
    bool clearError = false,
    bool clearPost = false,
  }) {
    return PostDetailState(
      status: status ?? this.status,
      post: clearPost ? null : post ?? this.post,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, post, errorMessage];
}
