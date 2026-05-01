part of 'create_post_bloc.dart';

sealed class CreatePostEvent extends Equatable {
  const CreatePostEvent();

  @override
  List<Object?> get props => const [];
}

/// Установить контекст автора (uid + denorm-имя/аватар) и опциональную
/// группу, в которую постим. Вызывается, когда экран открывается.
final class CreatePostInitialized extends CreatePostEvent {
  const CreatePostInitialized({
    required this.authorId,
    required this.authorName,
    this.authorPhotoUrl,
    this.groupId,
    this.groupName,
  });

  final String authorId;
  final String authorName;
  final String? authorPhotoUrl;
  final String? groupId;
  final String? groupName;

  @override
  List<Object?> get props => [
    authorId,
    authorName,
    authorPhotoUrl,
    groupId,
    groupName,
  ];
}

final class CreatePostPhotosPicked extends CreatePostEvent {
  const CreatePostPhotosPicked(this.files);
  final List<File> files;

  @override
  List<Object?> get props => [files.map((f) => f.path).toList()];
}

final class CreatePostPhotoRemoved extends CreatePostEvent {
  const CreatePostPhotoRemoved(this.index);
  final int index;

  @override
  List<Object?> get props => [index];
}

final class CreatePostDrinkNameChanged extends CreatePostEvent {
  const CreatePostDrinkNameChanged(this.value);
  final String value;

  @override
  List<Object?> get props => [value];
}

/// Бренд выбран в `BrandPickerSheet`. Передаём оба поля сразу
/// (`brandId` обязателен — `EnsureBrand` гарантирует, что документ
/// бренда уже существует).
final class CreatePostBrandSelected extends CreatePostEvent {
  const CreatePostBrandSelected({
    required this.brandId,
    required this.brandName,
  });
  final String brandId;
  final String brandName;

  @override
  List<Object?> get props => [brandId, brandName];
}

/// Сбросить выбранный бренд (кнопка-крестик у поля «Бренд»).
final class CreatePostBrandCleared extends CreatePostEvent {
  const CreatePostBrandCleared();
}

final class CreatePostFoundDateChanged extends CreatePostEvent {
  const CreatePostFoundDateChanged(this.value);
  final DateTime value;

  @override
  List<Object?> get props => [value];
}

final class CreatePostRarityChanged extends CreatePostEvent {
  const CreatePostRarityChanged(this.value);
  final int value;

  @override
  List<Object?> get props => [value];
}

final class CreatePostTagsChanged extends CreatePostEvent {
  const CreatePostTagsChanged(this.value);
  final List<String> value;

  @override
  List<Object?> get props => [value];
}

final class CreatePostDescriptionChanged extends CreatePostEvent {
  const CreatePostDescriptionChanged(this.value);
  final String value;

  @override
  List<Object?> get props => [value];
}

final class CreatePostGroupChanged extends CreatePostEvent {
  const CreatePostGroupChanged({this.groupId, this.groupName});
  final String? groupId;
  final String? groupName;

  @override
  List<Object?> get props => [groupId, groupName];
}

/// Sprint 14: пользователь отсканировал штрих-код, и в коллективной
/// базе уже есть запись. Подставляем поля автозаполнения.
/// `contributedBy=null`/`isKnown=true` означает, что contribute-back
/// при submit'е делать не нужно — запись уже есть.
final class CreatePostBarcodeMatched extends CreatePostEvent {
  const CreatePostBarcodeMatched({
    required this.code,
    required this.drinkName,
    this.brandId,
    this.brandName,
  });

  final String code;
  final String drinkName;
  final String? brandId;
  final String? brandName;

  @override
  List<Object?> get props => [code, drinkName, brandId, brandName];
}

/// Sprint 14: пользователь отсканировал штрих-код, но в базе записи
/// нет. Сохраняем код в стейте и помечаем `barcodeContribute=true`,
/// чтобы после успешного создания поста BLoC выполнил `SaveBarcode`.
final class CreatePostBarcodeUnknown extends CreatePostEvent {
  const CreatePostBarcodeUnknown({required this.code});
  final String code;

  @override
  List<Object?> get props => [code];
}

/// Sprint 14: сбросить отсканированный штрих-код (если пользователь
/// передумал автозаполнять).
final class CreatePostBarcodeCleared extends CreatePostEvent {
  const CreatePostBarcodeCleared();
}

final class CreatePostSubmitted extends CreatePostEvent {
  const CreatePostSubmitted();
}

final class CreatePostCreationAcknowledged extends CreatePostEvent {
  const CreatePostCreationAcknowledged();
}

final class CreatePostResetRequested extends CreatePostEvent {
  const CreatePostResetRequested();
}
