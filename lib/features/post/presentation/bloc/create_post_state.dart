part of 'create_post_bloc.dart';

enum CreatePostStatus { initial, uploading, creating, created, error }

class CreatePostAuthor extends Equatable {
  const CreatePostAuthor({required this.id, required this.name, this.photoUrl});

  final String id;
  final String name;
  final String? photoUrl;

  @override
  List<Object?> get props => [id, name, photoUrl];
}

final class CreatePostState extends Equatable {
  const CreatePostState({
    this.status = CreatePostStatus.initial,
    this.author,
    this.pickedFiles = const <File>[],
    this.drinkName = '',
    this.brandId,
    this.brandName = '',
    this.description = '',
    this.foundDate,
    this.rarity = 5,
    this.tags = const <String>[],
    this.groupId,
    this.groupName,
    this.uploadedCount = 0,
    this.totalCount = 0,
    this.errorMessage,
    this.createdPostId,
  });

  const CreatePostState.initial() : this();

  final CreatePostStatus status;
  final CreatePostAuthor? author;
  final List<File> pickedFiles;
  final String drinkName;
  final String? brandId;
  final String brandName;
  final String description;
  final DateTime? foundDate;
  final int rarity;
  final List<String> tags;
  final String? groupId;
  final String? groupName;
  final int uploadedCount;
  final int totalCount;
  final String? errorMessage;
  final String? createdPostId;

  bool get isUploading => status == CreatePostStatus.uploading;
  bool get isCreating => status == CreatePostStatus.creating;
  bool get isBusy => isUploading || isCreating;
  bool get canSubmit =>
      !isBusy && pickedFiles.isNotEmpty && drinkName.trim().length >= 2;

  CreatePostState copyWith({
    CreatePostStatus? status,
    CreatePostAuthor? author,
    List<File>? pickedFiles,
    String? drinkName,
    String? brandId,
    String? brandName,
    bool clearBrand = false,
    String? description,
    DateTime? foundDate,
    int? rarity,
    List<String>? tags,
    String? groupId,
    String? groupName,
    int? uploadedCount,
    int? totalCount,
    String? errorMessage,
    String? createdPostId,
    bool clearError = false,
    bool clearCreatedId = false,
    bool clearGroup = false,
  }) {
    return CreatePostState(
      status: status ?? this.status,
      author: author ?? this.author,
      pickedFiles: pickedFiles ?? this.pickedFiles,
      drinkName: drinkName ?? this.drinkName,
      brandId: clearBrand ? null : (brandId ?? this.brandId),
      brandName: clearBrand ? '' : (brandName ?? this.brandName),
      description: description ?? this.description,
      foundDate: foundDate ?? this.foundDate,
      rarity: rarity ?? this.rarity,
      tags: tags ?? this.tags,
      groupId: clearGroup ? null : (groupId ?? this.groupId),
      groupName: clearGroup ? null : (groupName ?? this.groupName),
      uploadedCount: uploadedCount ?? this.uploadedCount,
      totalCount: totalCount ?? this.totalCount,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      createdPostId: clearCreatedId
          ? null
          : (createdPostId ?? this.createdPostId),
    );
  }

  @override
  List<Object?> get props => [
    status,
    author,
    pickedFiles.map((f) => f.path).toList(),
    drinkName,
    brandId,
    brandName,
    description,
    foundDate,
    rarity,
    tags,
    groupId,
    groupName,
    uploadedCount,
    totalCount,
    errorMessage,
    createdPostId,
  ];
}
