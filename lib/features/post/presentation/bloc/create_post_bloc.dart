import 'dart:async';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/usecases/usecase.dart';
import '../../../barcode/domain/usecases/save_barcode.dart';
import '../../../group/domain/usecases/watch_my_groups.dart';
import '../../domain/entities/drink_rating.dart';
import '../../domain/entities/drink_type.dart';
import '../../domain/entities/post.dart';
import '../../domain/usecases/capture_photo_with_crop.dart';
import '../../domain/usecases/clear_last_selected_group.dart';
import '../../domain/usecases/create_post.dart';
import '../../domain/usecases/get_last_selected_group.dart';
import '../../domain/usecases/save_last_selected_group.dart';
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
  CreatePostBloc(
    this._createPost,
    this._uploadPostImage,
    this._saveBarcode,
    this._getLastSelectedGroup,
    this._saveLastSelectedGroup,
    this._clearLastSelectedGroup,
    this._capturePhotoWithCrop,
    this._watchMyGroups,
  ) : super(const CreatePostState.initial()) {
    on<CreatePostInitialized>(_onInitialized);
    on<CreatePostPhotosPicked>(_onPhotosPicked);
    on<CreatePostCameraRequested>(_onCameraRequested);
    on<CreatePostPhotoRemoved>(_onPhotoRemoved);
    on<CreatePostDrinkNameChanged>(_onDrinkNameChanged);
    on<CreatePostBrandSelected>(_onBrandSelected);
    on<CreatePostBrandCleared>(_onBrandCleared);
    on<CreatePostFlavorSelected>(_onFlavorSelected);
    on<CreatePostFlavorCleared>(_onFlavorCleared);
    on<CreatePostBarcodeMatched>(_onBarcodeMatched);
    on<CreatePostBarcodeUnknown>(_onBarcodeUnknown);
    on<CreatePostBarcodeCleared>(_onBarcodeCleared);
    on<CreatePostFoundDateChanged>(_onFoundDateChanged);
    on<CreatePostRatingEnabled>(_onRatingEnabled);
    on<CreatePostRatingChanged>(_onRatingChanged);
    on<CreatePostDrinkTypeChanged>(_onDrinkTypeChanged);
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
  final GetLastSelectedGroup _getLastSelectedGroup;
  final SaveLastSelectedGroup _saveLastSelectedGroup;
  final ClearLastSelectedGroup _clearLastSelectedGroup;
  final CapturePhotoWithCrop _capturePhotoWithCrop;
  final WatchMyGroups _watchMyGroups;

  Future<void> _onInitialized(
    CreatePostInitialized event,
    Emitter<CreatePostState> emit,
  ) async {
    // Устанавливаем данные автора
    emit(
      state.copyWith(
        author: CreatePostAuthor(
          id: event.authorId,
          name: event.authorName,
          photoUrl: event.authorPhotoUrl,
        ),
        clearError: true,
      ),
    );

    // Если группа передана явно (например, из экрана группы), используем её
    if (event.groupId != null) {
      emit(state.copyWith(groupId: event.groupId, groupName: event.groupName));
      return;
    }

    // Иначе пытаемся загрузить последнюю выбранную группу
    final lastGroupResult = await _getLastSelectedGroup();

    await lastGroupResult.fold(
      // Игнорируем ошибки чтения — просто не автовыбираем группу
      (_) async {},
      (groupId) async {
        if (groupId == null) return;

        // Проверяем, что пользователь всё ещё состоит в этой группе
        final myGroupsStream = _watchMyGroups(event.authorId);

        await for (final groupsResult in myGroupsStream.take(1)) {
          await groupsResult.fold(
            // Игнорируем ошибки загрузки групп
            (_) async {},
            (myGroups) async {
              // Ищем сохранённую группу среди текущих групп пользователя
              final group = myGroups.cast<dynamic>().firstWhere(
                (g) => g.id == groupId,
                orElse: () => null,
              );

              if (group != null) {
                // Группа найдена — автовыбираем её
                emit(
                  state.copyWith(
                    groupId: group.id as String,
                    groupName: group.name as String,
                    isGroupAutoSelected: true,
                  ),
                );
              } else {
                // Группа не найдена (удалена или пользователь вышел) — очищаем
                await _clearLastSelectedGroup();
              }
            },
          );
        }
      },
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

  /// Обработчик запроса захвата фото с камеры.
  /// Вызывает use case `CapturePhotoWithCrop` для получения фото с кропом 1:1,
  /// затем добавляет его в список фото (с ограничением до 6 фото).
  Future<void> _onCameraRequested(
    CreatePostCameraRequested event,
    Emitter<CreatePostState> emit,
  ) async {
    // Проверяем, не достигнут ли лимит фото
    if (state.pickedFiles.length >= _maxPhotos) {
      emit(
        state.copyWith(
          status: CreatePostStatus.error,
          errorMessage: 'Максимум $_maxPhotos фотографий',
        ),
      );
      return;
    }

    // Вызываем use case для захвата фото с камеры
    final result = await _capturePhotoWithCrop(const NoParams());

    result.fold(
      (failure) {
        // Обрабатываем ошибки захвата
        emit(
          state.copyWith(
            status: CreatePostStatus.error,
            errorMessage: failure.message ?? 'Не удалось захватить фото',
          ),
        );
      },
      (file) {
        // Добавляем захваченное фото в список
        final next = <File>[...state.pickedFiles, file];
        final capped = next.length > _maxPhotos
            ? next.sublist(0, _maxPhotos)
            : next;
        emit(state.copyWith(pickedFiles: capped, clearError: true));
      },
    );
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
  ) => emit(state.copyWith(clearBrand: true, clearFlavor: true));

  void _onFlavorSelected(
    CreatePostFlavorSelected event,
    Emitter<CreatePostState> emit,
  ) => emit(
    state.copyWith(flavorId: event.flavorId, flavorName: event.flavorName),
  );

  void _onFlavorCleared(
    CreatePostFlavorCleared event,
    Emitter<CreatePostState> emit,
  ) => emit(state.copyWith(clearFlavor: true));

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

  void _onRatingEnabled(
    CreatePostRatingEnabled event,
    Emitter<CreatePostState> emit,
  ) => emit(state.copyWith(isRated: event.enabled));

  void _onRatingChanged(
    CreatePostRatingChanged event,
    Emitter<CreatePostState> emit,
  ) => emit(state.copyWith(ratingDraft: event.rating, isRated: true));

  void _onDrinkTypeChanged(
    CreatePostDrinkTypeChanged event,
    Emitter<CreatePostState> emit,
  ) => emit(state.copyWith(drinkType: event.value));

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
      isGroupAutoSelected: false, // Сбрасываем флаг при ручном изменении
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
        flavorId: state.flavorId,
        flavorName: state.flavorName.trim().isEmpty
            ? null
            : state.flavorName.trim(),
        photos: uploaded,
        foundDate: state.foundDate ?? DateTime.now(),
        rating: state.isRated ? state.ratingDraft : null,
        drinkType: state.drinkType,
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

    // Сохраняем последнюю выбранную группу после успешного создания поста
    if (state.groupId != null) {
      await _saveLastSelectedGroup(state.groupId!);
      // Игнорируем ошибки сохранения — не блокируем пользовательский поток
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
