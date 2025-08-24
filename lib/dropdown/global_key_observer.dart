import 'package:flutter/material.dart';

class GlobalKeyObserver extends StatefulWidget {
  final Size size;
  final Offset position;
  final GlobalKey observable;
  final PositionedBuilder builder;

  final VoidCallback? onDisposed;

  const GlobalKeyObserver(
      {super.key,
      required this.size,
      required this.position,
      required this.builder,
      required this.observable,
      this.onDisposed});

  @override
  State<GlobalKeyObserver> createState() => _State();
}

typedef PositionedBuilder = Widget Function(
    BuildContext context, Size size, Offset position);

class _State extends State<GlobalKeyObserver> {
  late WidgetsBinding _binding;

  late ValueNotifier<_Value> _value;

  @override
  void initState() {
    _value =
        ValueNotifier(_Value(size: widget.size, position: widget.position));

    _binding = WidgetsBinding.instance;
    _binding.addPostFrameCallback(_tick);
    super.initState();
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _tick(_) {
    if (_disposed) return;

    final box =
        widget.observable.currentContext?.findRenderObject() as RenderBox?;
    final position = box?.localToGlobal(Offset.zero);

    if (box != null && position != null) {
      final next = _Value(size: box.size, position: position);

      if (_value.value.approxDifferent(next, 0.5)) {
        _value.value = next;
      }

      _binding.addPostFrameCallback(_tick);
    } else {
      widget.onDisposed?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<_Value>(
        valueListenable: _value,
        builder: (context, value, _) {
          return widget.builder.call(context, value.size, value.position);
        });
  }
}

class _Value {
  final Size size;
  final Offset position;

  _Value({required this.size, required this.position});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _Value &&
          runtimeType == other.runtimeType &&
          size == other.size &&
          position == other.position;

  @override
  int get hashCode => Object.hash(size, position);

  bool approxDifferent(_Value other, double eps) {
    return (size.width - other.size.width).abs() > eps ||
        (size.height - other.size.height).abs() > eps ||
        (position.dx - other.position.dx).abs() > eps ||
        (position.dy - other.position.dy).abs() > eps;
  }
}
