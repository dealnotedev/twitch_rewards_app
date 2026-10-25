import 'dart:async';

/// Tracks completion separately from scheduling: background actions still let
/// the next reaction start immediately, but settlement waits for their result.
class RewardExecution {
  final _pending = <Future<void>>[];
  final _cancellations = <Future<void> Function()>[];
  Object? _error;
  StackTrace? _stack;
  bool canceled = false;
  final _failed = Completer<void>();
  Future<void> get failure => _failed.future;

  RewardExecution() {
    unawaited(_failed.future.catchError((Object _) {}));
  }

  void track(Future<void> effect, {Future<void> Function()? cancel}) {
    if (cancel != null) _cancellations.add(cancel);
    _pending.add(
      effect.then<void>(
        (_) {},
        onError: (Object error, StackTrace stack) {
          _error ??= error;
          _stack ??= stack;
          if (!_failed.isCompleted) _failed.completeError(error, stack);
        },
      ),
    );
  }

  Future<void> finish() async {
    await Future.any<void>([
      Future.wait(_pending).then<void>((_) {}),
      _failed.future,
    ]);
    if (_error != null) Error.throwWithStackTrace(_error!, _stack!);
    if (canceled) throw StateError('Reaction canceled');
  }

  Future<void> cancel() async {
    canceled = true;
    await Future.wait(
      _cancellations.map((cancel) async {
        try {
          await cancel();
        } catch (_) {
          /* Settlement must still be retried. */
        }
      }),
    );
  }
}
