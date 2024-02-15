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
