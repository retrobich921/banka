import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/typedefs.dart';
import '../repositories/post_repository.dart';

@lazySingleton
class UpdatePost implements UseCase<void, UpdatePostParams> {
  const UpdatePost(this._repository);

  final PostRepository _repository;

  @override
  ResultFuture<void> call(UpdatePostParams params) {
    return _repository.updatePost(
      postId: params.postId,
      drinkName: params.drinkName,
      brandId: params.brandId,
      brandName: params.brandName,
      foundDate: params.foundDate,
      rarity: params.rarity,
      description: params.description,
      tags: params.tags,
    );
  }
}

class UpdatePostParams extends Equatable {
  const UpdatePostParams({
    required this.postId,
    this.drinkName,
    this.brandId,
    this.brandName,
    this.foundDate,
    this.rarity,
    this.description,
    this.tags,
  });

  final String postId;
  final String? drinkName;
  final String? brandId;
  final String? brandName;
  final DateTime? foundDate;
  final int? rarity;
  final String? description;
  final List<String>? tags;

  @override
  List<Object?> get props => [
    postId,
    drinkName,
    brandId,
    brandName,
    foundDate,
    rarity,
    description,
    tags,
  ];
}
