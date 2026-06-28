import 'package:freezed_annotation/freezed_annotation.dart';

part 'username_validation_result.freezed.dart';

/// Результат валидации username.
///
/// Используется для предоставления обратной связи пользователю при редактировании
/// username в профиле. Содержит четыре варианта:
/// - [valid]: Username валиден и доступен
/// - [invalid]: Username не соответствует формату (с описанием причины)
/// - [taken]: Username уже занят другим пользователем
/// - [cooldownActive]: Изменение username заблокировано cooldown'ом (30 дней)
@freezed
sealed class UsernameValidationResult with _$UsernameValidationResult {
  /// Username валиден и доступен для использования
  const factory UsernameValidationResult.valid() = _Valid;

  /// Username не соответствует формату (длина, символы, начинается с цифры и т.д.)
  const factory UsernameValidationResult.invalid(String reason) = _Invalid;

  /// Username уже занят другим пользователем
  const factory UsernameValidationResult.taken() = _Taken;

  /// Изменение username заблокировано cooldown'ом (30 дней с последнего изменения)
  const factory UsernameValidationResult.cooldownActive({
    required DateTime nextAvailableDate,
  }) = _CooldownActive;
}
