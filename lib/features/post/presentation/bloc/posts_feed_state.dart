part of 'posts_feed_bloc.dart';

enum PostsFeedStatus { initial, loading, ready, error }

/// Скоуп ленты: глобальная, посты группы или посты бренда.
final class PostsFeedScope extends Equatable {
  const PostsFeedScope.global() : groupId = null, brandId = null;
  const PostsFeedScope.group(String this.groupId) : brandId = null;
  const PostsFeedScope.brand(String this.brandId) : groupId = null;

  final String? groupId;
  final String? brandId;

  bool get isGlobal => groupId == null && brandId == null;
  bool get isGroup => groupId != null;
  bool get isBrand => brandId != null;

  @override
  List<Object?> get props => [groupId, brandId];
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
