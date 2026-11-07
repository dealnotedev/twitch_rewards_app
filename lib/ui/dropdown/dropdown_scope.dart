import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:twitch_listener/ui/dropdown/global_key_observer.dart';

/// Whether a popup follows its anchor or sizes itself to its contents.
enum DropdownMenuWidth { anchor, content }

class DropdownScope extends InheritedWidget {
  final DropdownManager manager;

  const DropdownScope({super.key, required this.manager, required super.child});

  static DropdownManager of(BuildContext context) {
    final widget = context
        .getElementForInheritedWidgetOfExactType<DropdownScope>()
        ?.widget;
    return ((widget as DropdownScope?)?.manager)!;
  }

  @override
  bool updateShouldNotify(covariant DropdownScope oldWidget) =>
      manager != oldWidget.manager;
}

class DropdownNavigationObserver extends NavigatorObserver {
  final DropdownManager manager;

  DropdownNavigationObserver({required this.manager});

  @override
  void didPop(Route route, Route? previousRoute) {
    manager.clear();
    super.didPop(route, previousRoute);
  }

  @override
  void didPush(Route route, Route? previousRoute) {
    manager.clear();
    super.didPush(route, previousRoute);
  }
}

class DropdownManager {
  _Handle? _current;

  final Offset offset;

  DropdownManager({this.offset = Offset.zero});

  void show(
    BuildContext context, {
    required WidgetBuilder builder,
    required GlobalKey key,
    DropdownMenuWidth menuWidth = DropdownMenuWidth.anchor,
    AlignmentGeometry alignment = AlignmentDirectional.topStart,
  }) {
    _current?.entry.remove();
    _current = null;

    final box = key.currentContext?.findRenderObject() as RenderBox?;
    final position = box?.localToGlobal(Offset.zero);

    if (box == null || position == null) return;

    final entry = OverlayEntry(
      builder: (c) {
        return GlobalKeyObserver(
          size: box.size,
          position: position,
          builder: (cntx, size, position) {
            final menu = builder(cntx);
            return CustomSingleChildLayout(
              delegate: _DropdownPositionDelegate(
                anchor: (position + offset) & size,
                menuWidth: menuWidth,
                alignment: alignment.resolve(Directionality.of(cntx)),
              ),
              child: menuWidth == DropdownMenuWidth.content
                  ? IntrinsicWidth(child: menu)
                  : menu,
            );
          },
          onDisposed: () => dismiss(key),
          observable: key,
        );
      },
    );

    _current = _Handle(key: key, entry: entry);

    Overlay.of(context).insert(entry);
  }

  void dismiss(GlobalKey key) {
    if (_current?.key == key) {
      _current?.entry.remove();
      _current = null;
    }
  }

  void clear() {
    _current?.entry.remove();
    _current = null;
  }
}

class _DropdownPositionDelegate extends SingleChildLayoutDelegate {
  static const _margin = 8.0;
  static const _gap = 4.0;

  final Rect anchor;
  final DropdownMenuWidth menuWidth;
  final Alignment alignment;

  _DropdownPositionDelegate({
    required this.anchor,
    required this.menuWidth,
    required this.alignment,
  });

  double _below(Size size) =>
      math.max(0.0, size.height - _margin - anchor.bottom - _gap);

  double _above() => math.max(0.0, anchor.top - _margin - _gap);

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final maxWidth = math.max(0.0, constraints.maxWidth - _margin * 2);
    final anchorWidth = math.min(anchor.width, maxWidth);
    return BoxConstraints(
      minWidth: menuWidth == DropdownMenuWidth.anchor ? anchorWidth : 0,
      maxWidth: menuWidth == DropdownMenuWidth.anchor ? anchorWidth : maxWidth,
      maxHeight: math.min(
        math.max(0.0, constraints.maxHeight - _margin * 2),
        math.max(_below(constraints.biggest), _above()),
      ),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final horizontalFraction = (alignment.x + 1) / 2;
    final left =
        anchor.left + (anchor.width - childSize.width) * horizontalFraction;
    final below = _below(size);
    final top = childSize.height <= below || below >= _above()
        ? anchor.bottom + _gap
        : anchor.top - _gap - childSize.height;
    return Offset(
      left.clamp(
        _margin,
        math.max(_margin, size.width - _margin - childSize.width),
      ),
      top.clamp(
        _margin,
        math.max(_margin, size.height - _margin - childSize.height),
      ),
    );
  }

  @override
  bool shouldRelayout(_DropdownPositionDelegate oldDelegate) =>
      anchor != oldDelegate.anchor ||
      menuWidth != oldDelegate.menuWidth ||
      alignment != oldDelegate.alignment;
}

class _Handle {
  final GlobalKey key;
  final OverlayEntry entry;

  _Handle({required this.key, required this.entry});
}
