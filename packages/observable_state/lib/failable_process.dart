/// A process without an operation token.
typedef SimpleFailableProcess = FailableProcess<void>;

/// State of one operation: idle, running, or failed until the next attempt.
///
/// Successful results belong to the surrounding state. Success returns the
/// process to [FailableProcess.initial]. [T] identifies mutually exclusive
/// operations; independent concurrent operations need independent processes.
sealed class FailableProcess<T> {
  const FailableProcess();

  const factory FailableProcess.initial() = InitialProcess<T>;
  const factory FailableProcess.loading([T? token]) = LoadingProcess<T>;
  const factory FailableProcess.failed(
    Object error, {
    T? token,
    Object? cause,
    StackTrace? stackTrace,
  }) = FailedProcess<T>;

  bool get isActive => this is LoadingProcess<T>;
  bool get isFailed => this is FailedProcess<T>;

  T? get token => switch (this) {
    LoadingProcess<T>(:final token) => token,
    FailedProcess<T>(:final token) => token,
    InitialProcess<T>() => null,
  };

  Object? get error => switch (this) {
    FailedProcess<T>(:final error) => error,
    _ => null,
  };
}

final class InitialProcess<T> extends FailableProcess<T> {
  const InitialProcess();
}

final class LoadingProcess<T> extends FailableProcess<T> {
  const LoadingProcess([this.token]);
  @override
  final T? token;
}

final class FailedProcess<T> extends FailableProcess<T> {
  const FailedProcess(this.error, {this.token, this.cause, this.stackTrace});
  @override
  final Object error;
  @override
  final T? token;

  /// Original exception and stack for diagnostics; UI renders [error].
  final Object? cause;
  final StackTrace? stackTrace;
}
