import 'package:flutter/material.dart';
import 'package:gap/gap.dart' show Gap;
import 'package:twitch_listener/dropdown/global_key_observer.dart';

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

  DropdownManager();

  void show(BuildContext context,
      {required WidgetBuilder builder, required GlobalKey key}) {
    _current?.entry.remove();
    _current = null;

    final box = key.currentContext?.findRenderObject() as RenderBox?;
    final position = box?.localToGlobal(Offset.zero);

    if (box == null || position == null) return;

    final entry = OverlayEntry(builder: (c) {
      return GlobalKeyObserver(
          size: box.size,
          position: position,
          builder: (cntx, size, position) {
            final h = MediaQuery.sizeOf(context).height;
            return Stack(
              children: [
                Positioned(
                  top: position.dy,
                  left: position.dx,
                  width: size.width,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Gap(size.height),
                      const Gap(4),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                            minHeight: 0,
                            maxHeight: h - position.dy - size.height - 4),
                        child: builder.call(cntx),
                      )
                    ],
                  ),
                )
              ],
            );
          },
          observable: key);
    });

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

class _Handle {
  final GlobalKey key;
  final OverlayEntry entry;

  _Handle({required this.key, required this.entry});
}
