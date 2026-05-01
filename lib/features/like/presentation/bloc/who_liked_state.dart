part of 'who_liked_bloc.dart';

enum WhoLikedStatus { initial, loading, ready, error }

final class WhoLikedState extends Equatable {
  const WhoLikedState({
    this.status = WhoLikedStatus.initial,
    this.likes = const <Like>[],
    this.errorMessage,
  });

  const WhoLikedState.initial() : this();

  final WhoLikedStatus status;
  final List<Like> likes;
  final String? errorMessage;

  bool get isLoading =>
      status == WhoLikedStatus.loading || status == WhoLikedStatus.initial;

  WhoLikedState copyWith({
    WhoLikedStatus? status,
    List<Like>? likes,
    String? errorMessage,
    bool clearError = false,
  }) {
    return WhoLikedState(
      status: status ?? this.status,
      likes: likes ?? this.likes,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, likes, errorMessage];
}
