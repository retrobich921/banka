part of 'like_button_cubit.dart';

enum LikeButtonStatus { initial, ready, mutating, error }

final class LikeButtonState extends Equatable {
  const LikeButtonState({
    this.status = LikeButtonStatus.initial,
    this.hasLiked = false,
    this.optimisticHasLiked,
    this.optimisticDelta = 0,
    this.errorMessage,
  });

  const LikeButtonState.initial() : this();

  final LikeButtonStatus status;
  final bool hasLiked;

  /// Желаемое значение, заявленное локальным тапом. Сбрасывается, как
  /// только стрим догоняет (или при ошибке).
  final bool? optimisticHasLiked;

  /// Поправка к `likesCount` родительского поста: +1 при оптимистичном
  /// лайке, -1 при анлайке, 0 — нет активной оптимистичной операции.
  final int optimisticDelta;

  final String? errorMessage;

  bool get displayedHasLiked => optimisticHasLiked ?? hasLiked;
  bool get isMutating => status == LikeButtonStatus.mutating;
  bool get isReady => status == LikeButtonStatus.ready;

  LikeButtonState copyWith({
    LikeButtonStatus? status,
    bool? hasLiked,
    bool? optimisticHasLiked,
    int? optimisticDelta,
    String? errorMessage,
    bool clearOptimistic = false,
    bool clearError = false,
  }) {
    return LikeButtonState(
      status: status ?? this.status,
      hasLiked: hasLiked ?? this.hasLiked,
      optimisticHasLiked: clearOptimistic
          ? null
          : optimisticHasLiked ?? this.optimisticHasLiked,
      optimisticDelta: optimisticDelta ?? this.optimisticDelta,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    status,
    hasLiked,
    optimisticHasLiked,
    optimisticDelta,
    errorMessage,
  ];
}
