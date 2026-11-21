/// Sealed failure hierarchy enabling exhaustive pattern matching in Dart 3.13+.
sealed class AppFailure {
  const AppFailure(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => '$runtimeType(code: $code, message: $message)';
}

final class NetworkFailure extends AppFailure {
  const NetworkFailure(super.message, {super.code});
}

final class CryptoFailure extends AppFailure {
  const CryptoFailure(super.message, {super.code});
}

final class AuthFailure extends AppFailure {
  const AuthFailure(super.message, {super.code});
}

final class RlsPermissionFailure extends AppFailure {
  const RlsPermissionFailure(super.message, {super.code});
}

final class ValidationFailure extends AppFailure {
  const ValidationFailure(super.message, {super.code});
}

/// Functional result type for pure domain operations.
sealed class Result<T> {
  const Result();

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is FailureResult<T>;

  T? get valueOrNull => switch (this) {
    Success<T>(:final value) => value,
    FailureResult<T>() => null,
  };

  AppFailure? get failureOrNull => switch (this) {
    Success<T>() => null,
    FailureResult<T>(:final failure) => failure,
  };

  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(AppFailure failure) onFailure,
  }) {
    return switch (this) {
      Success<T>(:final value) => onSuccess(value),
      FailureResult<T>(:final failure) => onFailure(failure),
    };
  }
}

final class Success<T> extends Result<T> {
  const Success(this.value);

  final T value;
}

final class FailureResult<T> extends Result<T> {
  const FailureResult(this.failure);

  final AppFailure failure;
}
