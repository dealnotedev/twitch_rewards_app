import 'dart:async';

import 'package:flutter/widgets.dart';

import 'observable_state.dart';

/// Builds from `source.current` and rebuilds when the source reports a change.
///
/// Replacing [source] with another object re-reads its snapshot. Pass a subtree
/// that does not depend on the value as [child] to avoid rebuilding it.
class ObservableBuilder<T> extends StatefulWidget {
  const ObservableBuilder({
    required this.source,
    required this.builder,
    this.child,
    super.key,
  });

  final Observable<T> source;
  final Widget Function(BuildContext context, T value, Widget? child) builder;
  final Widget? child;

  @override
  State<ObservableBuilder<T>> createState() => _ObservableBuilderState<T>();
}

class _ObservableBuilderState<T> extends State<ObservableBuilder<T>> {
  late T _value;
  StreamSubscription<T>? _subscription;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(ObservableBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.source, widget.source)) return;
    unawaited(_subscription?.cancel());
    _listen();
  }

  void _listen() {
    final source = widget.source;
    _value = source.current;
    _subscription = source.changes.listen((_) {
      // A deferred notification can be older than the snapshot already shown.
      final next = source.current;
      if (next != _value) setState(() => _value = next);
    });
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _value, widget.child);
}
