import '../utils/typedefs.dart';

/// Базовый контракт для асинхронных usecase'ов уровня домена.
///
/// `T` — тип результата, `Params` — типизированные параметры. Если параметры
/// не нужны, используй `NoParams`.
abstract interface class UseCase<T, Params> {
  ResultFuture<T> call(Params params);
}

/// То же, но возвращает поток. Используется для подписок (auth-state, ленты).
abstract interface class StreamUseCase<T, Params> {
  Stream<T> call(Params params);
}

/// Параметр-«заглушка» для usecase'ов без аргументов.
final class NoParams {
  const NoParams();
}
