import 'dart:async';

import 'package:rxdart/rxdart.dart';

class ObservableValue<T> {
  T current;

  final _subject = StreamController<T>.broadcast();

  ObservableValue({required this.current});

  Stream<T> get value => Stream.value(current).concatWith([_subject.stream]);

  void set(T value) {
    if (current != value) {
      current = value;
      _subject.add(value);
    }
  }

  void update(T Function(T current) updater) {
    set(updater.call(current));
  }

  void notifyUpdates() {
    _subject.add(current);
  }

  void apply(void Function(T current) fn) {
    fn(current);
    _subject.add(current);
  }

  void apply2(bool Function(T current) fn) {
    if (fn(current)) {
      _subject.add(current);
    }
  }

  Stream<T> get changes => _subject.stream;

  void dispose() {
    _subject.close();
  }
}

class ObservableValueUtils {
  ObservableValueUtils._();

  static Stream<R> combineObservableChanges2<A, B, R>(
    ObservableValue<A> a,
    ObservableValue<B> b,
    R Function(A a, B b) combiner,
  ) {
    final controller = StreamController<R>.broadcast();

    final subA =
        a.changes.listen((v) => controller.add(combiner(v, b.current)));
    final subB =
        b.changes.listen((v) => controller.add(combiner(a.current, v)));

    controller.onCancel = () {
      subA.cancel();
      subB.cancel();
    };

    return controller.stream;
  }

  static Stream<R> combineObservableChanges3<A, B, C, R>(
    ObservableValue<A> a,
    ObservableValue<B> b,
      ObservableValue<C> c,
    R Function(A a, B b, C c) combiner,
  ) {
    final controller = StreamController<R>.broadcast();

    final subA = a.changes.listen(
      (v) => controller.add(combiner(v, b.current, c.current)),
    );
    final subB = b.changes.listen(
      (v) => controller.add(combiner(a.current, v, c.current)),
    );
    final subC = c.changes.listen(
      (v) => controller.add(combiner(a.current, b.current, v)),
    );

    controller.onCancel = () {
      subA.cancel();
      subB.cancel();
      subC.cancel();
    };

    return controller.stream;
  }
}
