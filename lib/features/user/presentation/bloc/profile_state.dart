part of 'profile_bloc.dart';

enum ProfileStatus { initial, loading, ready, saving, error }

final class ProfileState extends Equatable {
  const ProfileState({
    this.status = ProfileStatus.initial,
    this.profile,
    this.errorMessage,
    this.usernameValidation,
    this.isValidatingUsername = false,
  });

  const ProfileState.initial() : this();

  final ProfileStatus status;
  final UserProfile? profile;
  final String? errorMessage;
  final UsernameValidationResult? usernameValidation;
  final bool isValidatingUsername;

  bool get isReady => status == ProfileStatus.ready && profile != null;
  bool get isSaving => status == ProfileStatus.saving;
  bool get isLoading => status == ProfileStatus.loading;

  ProfileState copyWith({
    ProfileStatus? status,
    UserProfile? profile,
    String? errorMessage,
    UsernameValidationResult? usernameValidation,
    bool? isValidatingUsername,
    bool clearError = false,
    bool clearValidation = false,
  }) {
    return ProfileState(
      status: status ?? this.status,
      profile: profile ?? this.profile,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      usernameValidation: clearValidation
          ? null
          : (usernameValidation ?? this.usernameValidation),
      isValidatingUsername: isValidatingUsername ?? this.isValidatingUsername,
    );
  }

  @override
  List<Object?> get props => [
    status,
    profile,
    errorMessage,
    usernameValidation,
    isValidatingUsername,
  ];
}
