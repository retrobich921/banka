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

/// Поток c обёрткой `Either<Failure, T>` — для real-time источников, где
/// важно различать «нет данных» и «ошибка чтения» (Firestore-стримы).
abstract interface class StreamResultUseCase<T, Params> {
  ResultStream<T> call(Params params);
}

/// Параметр-«заглушка» для usecase'ов без аргументов.
final class NoParams {
  const NoParams();
}
