import 'dart:async';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../barcode/domain/usecases/save_barcode.dart';
import '../../domain/entities/post.dart';
import '../../domain/usecases/create_post.dart';
import '../../domain/usecases/upload_post_image.dart';

part 'create_post_event.dart';
part 'create_post_state.dart';

/// BLoC формы создания поста-«банки».
///
/// Поток:
/// 1. Поля редактируются по событиям `*Changed` — это чистый редьюсер.
/// 2. По `CreatePostSubmitted` сначала загружаем все выбранные файлы в
///    Storage (status = uploading, отдаём прогресс
///    `uploadedCount / totalCount`).
/// 3. Затем создаём документ Firestore (status = creating).
/// 4. После успеха status = created, экран сам уходит на детальный.
/// 5. `CreatePostCreationAcknowledged` сбрасывает `createdPostId`, чтобы
///    listener в UI отработал ровно один раз.
///
/// Storage-путь: `posts/{tempPostId}/{n}_{filename}`. `tempPostId`
/// генерируется на старте submit'а, фактический `Post.id` определяет
/// data-source при `createPost`. Это значит, что Storage-файлы лежат под
/// «временным» префиксом, а Cloud Function `onPostImageUploaded` всё
/// равно их найдёт по списку `posts.{postId}.photos[].url`.
@injectable
class CreatePostBloc extends Bloc<CreatePostEvent, CreatePostState> {
  CreatePostBloc(this._createPost, this._uploadPostImage, this._saveBarcode)
    : super(const CreatePostState.initial()) {
    on<CreatePostInitialized>(_onInitialized);
    on<CreatePostPhotosPicked>(_onPhotosPicked);
    on<CreatePostPhotoRemoved>(_onPhotoRemoved);
    on<CreatePostDrinkNameChanged>(_onDrinkNameChanged);
    on<CreatePostBrandSelected>(_onBrandSelected);
    on<CreatePostBrandCleared>(_onBrandCleared);
    on<CreatePostBarcodeMatched>(_onBarcodeMatched);
    on<CreatePostBarcodeUnknown>(_onBarcodeUnknown);
    on<CreatePostBarcodeCleared>(_onBarcodeCleared);
    on<CreatePostFoundDateChanged>(_onFoundDateChanged);
    on<CreatePostRarityChanged>(_onRarityChanged);
    on<CreatePostTagsChanged>(_onTagsChanged);
    on<CreatePostDescriptionChanged>(_onDescriptionChanged);
    on<CreatePostGroupChanged>(_onGroupChanged);
    on<CreatePostSubmitted>(_onSubmitted);
    on<CreatePostCreationAcknowledged>(_onCreationAcknowledged);
    on<CreatePostResetRequested>(_onResetRequested);
  }

  final CreatePost _createPost;
  final UploadPostImage _uploadPostImage;
  final SaveBarcode _saveBarcode;

  void _onInitialized(
    CreatePostInitialized event,
    Emitter<CreatePostState> emit,
  ) {
    emit(
      state.copyWith(
        author: CreatePostAuthor(
          id: event.authorId,
          name: event.authorName,
          photoUrl: event.authorPhotoUrl,
        ),
        groupId: event.groupId,
        groupName: event.groupName,
        clearError: true,
      ),
    );
  }

  void _onPhotosPicked(
    CreatePostPhotosPicked event,
    Emitter<CreatePostState> emit,
  ) {
    if (event.files.isEmpty) return;
    final next = <File>[...state.pickedFiles, ...event.files];
    final capped = next.length > _maxPhotos
        ? next.sublist(0, _maxPhotos)
        : next;
    emit(state.copyWith(pickedFiles: capped, clearError: true));
  }

  void _onPhotoRemoved(
    CreatePostPhotoRemoved event,
    Emitter<CreatePostState> emit,
  ) {
    if (event.index < 0 || event.index >= state.pickedFiles.length) return;
    final next = [...state.pickedFiles]..removeAt(event.index);
    emit(state.copyWith(pickedFiles: next));
  }

  void _onDrinkNameChanged(
    CreatePostDrinkNameChanged event,
    Emitter<CreatePostState> emit,
  ) => emit(state.copyWith(drinkName: event.value, clearError: true));

  void _onBrandSelected(
    CreatePostBrandSelected event,
    Emitter<CreatePostState> emit,
  ) => emit(state.copyWith(brandId: event.brandId, brandName: event.brandName));

  void _onBrandCleared(
    CreatePostBrandCleared event,
    Emitter<CreatePostState> emit,
  ) => emit(state.copyWith(clearBrand: true));

  void _onBarcodeMatched(
    CreatePostBarcodeMatched event,
    Emitter<CreatePostState> emit,
  ) {
    emit(
      state.copyWith(
        barcode: event.code,
        barcodeContribute: false,
        drinkName: event.drinkName,
        brandId: event.brandId,
        brandName: event.brandName ?? '',
        clearError: true,
      ),
    );
  }

  void _onBarcodeUnknown(
    CreatePostBarcodeUnknown event,
    Emitter<CreatePostState> emit,
  ) {
    emit(
      state.copyWith(
        barcode: event.code,
        barcodeContribute: true,
        clearError: true,
      ),
    );
  }

  void _onBarcodeCleared(
    CreatePostBarcodeCleared event,
    Emitter<CreatePostState> emit,
  ) => emit(state.copyWith(clearBarcode: true));

  void _onFoundDateChanged(
    CreatePostFoundDateChanged event,
    Emitter<CreatePostState> emit,
  ) => emit(state.copyWith(foundDate: event.value));

  void _onRarityChanged(
    CreatePostRarityChanged event,
    Emitter<CreatePostState> emit,
  ) {
    final clamped = event.value.clamp(1, 9);
    emit(state.copyWith(rarity: clamped));
  }

  void _onTagsChanged(
    CreatePostTagsChanged event,
    Emitter<CreatePostState> emit,
  ) => emit(state.copyWith(tags: event.value));

  void _onDescriptionChanged(
    CreatePostDescriptionChanged event,
    Emitter<CreatePostState> emit,
  ) => emit(state.copyWith(description: event.value));

  void _onGroupChanged(
    CreatePostGroupChanged event,
    Emitter<CreatePostState> emit,
  ) => emit(
    state.copyWith(
      groupId: event.groupId,
      groupName: event.groupName,
      clearGroup: event.groupId == null,
    ),
  );

  Future<void> _onSubmitted(
    CreatePostSubmitted event,
    Emitter<CreatePostState> emit,
  ) async {
    final author = state.author;
    if (author == null) {
      emit(
        state.copyWith(
          status: CreatePostStatus.error,
          errorMessage: 'Не загружен профиль автора',
        ),
      );
      return;
    }
    if (state.pickedFiles.isEmpty) {
      emit(
        state.copyWith(
          status: CreatePostStatus.error,
          errorMessage: 'Нужно прикрепить хотя бы одно фото',
        ),
      );
      return;
    }
    final drinkName = state.drinkName.trim();
    if (drinkName.length < 2) {
      emit(
        state.copyWith(
          status: CreatePostStatus.error,
          errorMessage: 'Введи название напитка (минимум 2 символа)',
        ),
      );
      return;
    }

    final tempPostId =
        'tmp_${DateTime.now().millisecondsSinceEpoch}_${author.id}';

    emit(
      state.copyWith(
        status: CreatePostStatus.uploading,
        uploadedCount: 0,
        totalCount: state.pickedFiles.length,
        clearError: true,
      ),
    );

    final uploaded = <PostPhoto>[];
    for (var i = 0; i < state.pickedFiles.length; i++) {
      final result = await _uploadPostImage(
        UploadPostImageParams(
          postId: tempPostId,
          index: i,
          file: state.pickedFiles[i],
        ),
      );
      final failure = result.fold((f) => f, (_) => null);
      if (failure != null) {
        emit(
          state.copyWith(
            status: CreatePostStatus.error,
            errorMessage:
                'Не удалось загрузить фото: ${failure.message ?? "—"}',
          ),
        );
        return;
      }
      final photo = result.getOrElse(() => throw StateError('unreachable'));
      uploaded.add(photo);
      emit(state.copyWith(uploadedCount: i + 1));
    }

    emit(state.copyWith(status: CreatePostStatus.creating));

    final created = await _createPost(
      CreatePostParams(
        authorId: author.id,
        authorName: author.name,
        authorPhotoUrl: author.photoUrl,
        drinkName: drinkName,
        groupId: state.groupId,
        groupName: state.groupName,
        brandId: state.brandId,
        brandName: state.brandName.trim().isEmpty
            ? null
            : state.brandName.trim(),
        photos: uploaded,
        foundDate: state.foundDate ?? DateTime.now(),
        rarity: state.rarity,
        description: state.description.trim(),
        tags: state.tags,
      ),
    );

    final post = created.fold((_) => null, (p) => p);
    if (post == null) {
      created.fold(
        (failure) => emit(
          state.copyWith(
            status: CreatePostStatus.error,
            errorMessage: failure.message ?? 'Не удалось создать пост',
          ),
        ),
        (_) {},
      );
      return;
    }

    // Sprint 14: contribute-back в коллективную базу штрих-кодов.
    // Делаем только если пользователь отсканировал новый код
    // (`barcodeContribute=true`). Ошибка здесь не ломает успех
    // создания поста — логируем и идём дальше.
    if (state.barcode != null && state.barcodeContribute) {
      await _saveBarcode(
        SaveBarcodeParams(
          code: state.barcode!,
          drinkName: drinkName,
          contributedBy: author.id,
          brandId: state.brandId,
          brandName: state.brandName.trim().isEmpty
              ? null
              : state.brandName.trim(),
          suggestedPhotoUrl: uploaded.firstOrNull?.url,
        ),
      );
    }

    emit(
      state.copyWith(status: CreatePostStatus.created, createdPostId: post.id),
    );
  }

  void _onCreationAcknowledged(
    CreatePostCreationAcknowledged event,
    Emitter<CreatePostState> emit,
  ) {
    emit(
      state.copyWith(
        status: CreatePostStatus.initial,
        clearCreatedId: true,
        clearError: true,
      ),
    );
  }

  void _onResetRequested(
    CreatePostResetRequested event,
    Emitter<CreatePostState> emit,
  ) {
    emit(const CreatePostState.initial());
  }
}

const int _maxPhotos = 6;
