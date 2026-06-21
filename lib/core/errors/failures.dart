/// Base Failure class representing an error state in the domain or infrastructure layers.
abstract class Failure {
  const Failure(this.message);

  /// A human-readable message describing the failure.
  final String message;

  @override
  String toString() => 'Failure(message: $message)';
}

/// Failure representing server-side or remote errors (network, API, etc.).
class ServerFailure extends Failure {
  const ServerFailure(super.message, {this.code});

  /// Optional server-side error code (HTTP status code, etc.).
  final int? code;

  @override
  String toString() => 'ServerFailure(code: $code, message: $message)';
}

/// Failure representing local persistence/cache related errors.
class CacheFailure extends Failure {
  const CacheFailure(super.message);

  @override
  String toString() => 'CacheFailure(message: $message)';
}
