import 'dart:async';
import 'dart:collection';

import 'package:meta/meta.dart';

export 'failable_process.dart';
export 'observable_builder.dart';

/// Read-only state with a synchronous snapshot and a stable change stream.
///
/// [current] is the source of truth; [changes] only signals that it changed.
/// An asynchronous source can notify after [current] has already moved on, so
/// consumers read [current] when notified instead of trusting the payload.
abstract interface class Observable<T> {
  /// An immutable source for a value that changes when its owner replaces it.
  const factory Observable.value(T current) = _FixedValue<T>;

  /// A read-only view over state owned elsewhere, such as a service's
  /// `state`/`states` pair. Create it once so its identity stays stable.
  factory Observable.of(T Function() read, Stream<T> changes) =
      _DelegatedValue<T>;

  T get current;
  Stream<T> get changes;
}

final class _FixedValue<T> implements Observable<T> {
  const _FixedValue(this.current);
  @override
  final T current;
  @override
  Stream<T> get changes => const Stream.empty(broadcast: true);
}

final class _DelegatedValue<T> implements Observable<T> {
  _DelegatedValue(this._read, this.changes);
  final T Function() _read;
  @override
  T get current => _read();
  @override
  final Stream<T> changes;
}

extension ObservableSelection<T> on Observable<T> {
  /// A stable read-only projection, notifying only when its selected value changes.
  /// Create it once; it follows the source's lifetime and exposes no writes.
  Observable<R> select<R>(R Function(T value) select) =>
      _SelectedValue(this, select);
}

final class _SelectedValue<T, R> implements Observable<R> {
  _SelectedValue(this._source, this._select) {
    changes = Stream<R>.multi((controller) {
      var previous = current;
      final subscription = _source.changes.listen(
        (_) {
          try {
            final next = current;
            if (next == previous) return;
            previous = next;
            controller.addSync(next);
          } catch (error, stack) {
            controller.addErrorSync(error, stack);
          }
        },
        onError: controller.addErrorSync,
        onDone: controller.closeSync,
      );
      controller.onCancel = subscription.cancel;
    }, isBroadcast: true);
  }

  final Observable<T> _source;
  final R Function(T value) _select;

  @override
  R get current => _select(_source.current);

  @override
  late final Stream<R> changes;
}

/// Owns a value with a current snapshot and change notifications.
///
/// Setting a value equal (`==`) to the current one changes nothing. Values are
/// immutable snapshots: publish a new object instead of mutating the current.
/// Notifications are synchronous by default; pass `sync: false` to defer them.
final class ObservableValue<T> implements Observable<T> {
  ObservableValue({required T current, bool sync = true})
    : _current = current,
      _changes = StreamController<T>.broadcast(sync: sync);

  T _current;
  final StreamController<T> _changes;
  final Queue<T> _notifications = Queue<T>();
  bool _notifying = false;
  bool _disposed = false;

  @override
  T get current => _current;

  @override
  Stream<T> get changes => _changes.stream;

  void set(T value, {bool notify = true}) {
    if (_disposed) throw StateError('ObservableValue is disposed');
    if (value == _current) return;
    _current = value;
    if (!notify) return;
    _notifications.add(value);
    if (_notifying) return;
    _notifying = true;
    try {
      // A synchronous listener may issue another intent. Deliver its change
      // only after every listener has received the preceding notification.
      while (_notifications.isNotEmpty && !_disposed) {
        _changes.add(_notifications.removeFirst());
      }
    } finally {
      _notifying = false;
      if (_disposed) unawaited(_changes.close());
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _notifications.clear();
    if (!_notifying) unawaited(_changes.close());
  }
}

/// Distinguishes an unchanged nullable field from one explicitly cleared.
final class Nullable<T> {
  const Nullable(this.value);
  final T? value;
}

extension NullableFallback<T> on Nullable<T>? {
  T? getOr(T? previous) => this == null ? previous : this!.value;
}

/// Owns registered observables and subscriptions for one presentation flow.
///
/// Subclasses dispose their timers/resources and call super.dispose() first so
/// pending asynchronous operations can check [isDisposed] before publishing.
/// Models initialize their final observables, wire subscriptions, and start
/// requests in the constructor. The base imposes no particular state shape.
abstract class BaseViewModel {
  final Set<ObservableValue<dynamic>> _observables = {};
  final Set<StreamSubscription<dynamic>> _subscriptions = {};
  bool _disposed = false;

  bool get isDisposed => _disposed;

  @protected
  ObservableValue<T> register<T>(ObservableValue<T> observable) {
    if (_disposed) throw StateError('ViewModel is disposed');
    _observables.add(observable);
    return observable;
  }

  @protected
  StreamSubscription<V> observe<V>(
    Stream<V> source,
    void Function(V value) onData,
  ) {
    if (_disposed) throw StateError('ViewModel is disposed');
    final subscription = source.listen((value) {
      if (!_disposed) onData(value);
    });
    _subscriptions.add(subscription);
    return subscription;
  }

  @protected
  void stopObserving(StreamSubscription<dynamic>? subscription) {
    if (subscription == null) return;
    _subscriptions.remove(subscription);
    unawaited(subscription.cancel());
  }

  @mustCallSuper
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
    for (final observable in _observables) {
      observable.dispose();
    }
    _observables.clear();
  }
}
