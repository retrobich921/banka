part of 'posts_feed_bloc.dart';

enum PostsFeedStatus { initial, loading, ready, error }

/// Скоуп ленты: глобальная, посты группы, бренда или конкретного автора
/// (последнее — для «Мои банки» в профиле).
final class PostsFeedScope extends Equatable {
  const PostsFeedScope.global()
    : groupId = null,
      brandId = null,
      authorId = null;
  const PostsFeedScope.group(String this.groupId)
    : brandId = null,
      authorId = null;
  const PostsFeedScope.brand(String this.brandId)
    : groupId = null,
      authorId = null;
  const PostsFeedScope.author(String this.authorId)
    : groupId = null,
      brandId = null;

  final String? groupId;
  final String? brandId;
  final String? authorId;

  bool get isGlobal =>
      groupId == null && brandId == null && authorId == null;
  bool get isGroup => groupId != null;
  bool get isBrand => brandId != null;
  bool get isAuthor => authorId != null;

  @override
  List<Object?> get props => [groupId, brandId, authorId];
}

final class PostsFeedState extends Equatable {
  const PostsFeedState({
    this.status = PostsFeedStatus.initial,
    this.scope,
    this.posts = const <Post>[],
    this.errorMessage,
    this.isLoadingMore = false,
    this.hasReachedEnd = false,
  });

  const PostsFeedState.initial() : this();

  final PostsFeedStatus status;
  final PostsFeedScope? scope;
  final List<Post> posts;
  final String? errorMessage;

  /// Идёт догрузка следующей страницы (нижний лоадер в ленте).
  final bool isLoadingMore;

  /// Достигнут конец ленты — подгружать больше нечего.
  final bool hasReachedEnd;

  bool get isLoading =>
      status == PostsFeedStatus.loading || status == PostsFeedStatus.initial;

  PostsFeedState copyWith({
    PostsFeedStatus? status,
    PostsFeedScope? scope,
    List<Post>? posts,
    String? errorMessage,
    bool clearError = false,
    bool? isLoadingMore,
    bool? hasReachedEnd,
  }) {
    return PostsFeedState(
      status: status ?? this.status,
      scope: scope ?? this.scope,
      posts: posts ?? this.posts,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasReachedEnd: hasReachedEnd ?? this.hasReachedEnd,
    );
  }

  @override
  List<Object?> get props => [
    status,
    scope,
    posts,
    errorMessage,
    isLoadingMore,
    hasReachedEnd,
  ];
}
