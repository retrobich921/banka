part of 'posts_feed_bloc.dart';

enum PostsFeedStatus { initial, loading, ready, error }

/// Скоуп ленты: либо глобальная, либо посты конкретной группы.
final class PostsFeedScope extends Equatable {
  const PostsFeedScope.global() : groupId = null;
  const PostsFeedScope.group(String this.groupId);

  final String? groupId;

  bool get isGlobal => groupId == null;

  @override
  List<Object?> get props => [groupId];
}

final class PostsFeedState extends Equatable {
  const PostsFeedState({
    this.status = PostsFeedStatus.initial,
    this.scope,
    this.posts = const <Post>[],
    this.errorMessage,
  });

  const PostsFeedState.initial() : this();

  final PostsFeedStatus status;
  final PostsFeedScope? scope;
  final List<Post> posts;
  final String? errorMessage;

  bool get isLoading =>
      status == PostsFeedStatus.loading || status == PostsFeedStatus.initial;

  PostsFeedState copyWith({
    PostsFeedStatus? status,
    PostsFeedScope? scope,
    List<Post>? posts,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PostsFeedState(
      status: status ?? this.status,
      scope: scope ?? this.scope,
      posts: posts ?? this.posts,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, scope, posts, errorMessage];
}
