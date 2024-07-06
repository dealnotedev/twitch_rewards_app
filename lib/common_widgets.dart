import 'package:flutter/material.dart';

class OnHoverVisibility extends StatefulWidget {
  final Widget child;

  const OnHoverVisibility({super.key, required this.child});

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<OnHoverVisibility> {
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _handleMouseEnter(true),
      onExit: (_) => _handleMouseEnter(false),
      child: Visibility(
        visible: _entered,
        maintainState: true,
        maintainSize: true,
        maintainAnimation: true,
        child: widget.child,
      ),
    );
  }

  bool _entered = false;

  void _handleMouseEnter(bool entered) {
    setState(() {
      _entered = entered;
    });
  }
}
