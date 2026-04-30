import 'package:dartz/dartz.dart';

import '../error/failures.dart';

/// Результат usecase: либо `Failure`, либо значение `T`.
typedef ResultFuture<T> = Future<Either<Failure, T>>;

/// Стрим для real-time источников (Firestore/FCM).
typedef ResultStream<T> = Stream<Either<Failure, T>>;

/// Универсальная JSON-карта.
typedef DataMap = Map<String, dynamic>;
