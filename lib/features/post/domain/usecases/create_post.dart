import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/typedefs.dart';
import '../entities/drink_type.dart';
import '../entities/post.dart';
import '../repositories/post_repository.dart';

@lazySingleton
class CreatePost implements UseCase<Post, CreatePostParams> {
  const CreatePost(this._repository);

  final PostRepository _repository;

  @override
  ResultFuture<Post> call(CreatePostParams params) {
    return _repository.createPost(
      authorId: params.authorId,
      authorName: params.authorName,
      authorPhotoUrl: params.authorPhotoUrl,
      drinkName: params.drinkName,
      groupId: params.groupId,
      groupName: params.groupName,
      brandId: params.brandId,
      brandName: params.brandName,
      flavorId: params.flavorId,
      flavorName: params.flavorName,
      photos: params.photos,
      foundDate: params.foundDate,
      rarity: params.rarity,
      tasteRating: params.tasteRating,
      drinkType: params.drinkType,
      description: params.description,
      tags: params.tags,
    );
  }
}

class CreatePostParams extends Equatable {
  const CreatePostParams({
    required this.authorId,
    required this.authorName,
    required this.drinkName,
    required this.photos,
    required this.foundDate,
    required this.rarity,
    this.tasteRating = 0,
    this.drinkType = DrinkType.energy,
    this.authorPhotoUrl,
    this.groupId,
    this.groupName,
    this.brandId,
    this.brandName,
    this.flavorId,
    this.flavorName,
    this.description = '',
    this.tags = const <String>[],
  });

  final String authorId;
  final String authorName;
  final String? authorPhotoUrl;
  final String drinkName;
  final String? groupId;
  final String? groupName;
  final String? brandId;
  final String? brandName;
  final String? flavorId;
  final String? flavorName;
  final List<PostPhoto> photos;
  final DateTime foundDate;
  final int rarity;
  final int tasteRating;
  final DrinkType drinkType;
  final String description;
  final List<String> tags;

  @override
  List<Object?> get props => [
    authorId,
    authorName,
    authorPhotoUrl,
    drinkName,
    groupId,
    groupName,
    brandId,
    brandName,
    flavorId,
    flavorName,
    photos,
    foundDate,
    rarity,
    tasteRating,
    drinkType,
    description,
    tags,
  ];
}
