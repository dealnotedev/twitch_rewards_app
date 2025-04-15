import 'dart:math';

import 'package:flutter/material.dart';

class RippleIcon extends StatelessWidget {
  final String? icon;
  final double size;
  final double padding;
  final EdgeInsets? margin;
  final Color? color;
  final VoidCallback? onTap;
  final FilterQuality? filterQuality;
  final Widget? iconWidget;

  final bool rotateIfRtl;
  final bool? rtl;
  final Color? background;

  const RippleIcon(
      {super.key,
      this.icon,
      required this.size,
      this.margin,
      this.padding = 8.0,
      this.color,
      this.rtl,
      this.rotateIfRtl = false,
      this.iconWidget,
      this.onTap,
      this.background,
      this.filterQuality});

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size / 2.0 + padding);
    final margin = this.margin;

    final icon = this.icon;
    final background = this.background;

    final result = Material(
      color: background,
      borderRadius: radius,
      type:
          background != null ? MaterialType.canvas : MaterialType.transparency,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          height: size + (padding * 2),
          width: size + (padding * 2),
          child: icon != null
              ? Image.asset(
                  icon,
                  filterQuality: filterQuality ?? FilterQuality.medium,
                  color: color,
                  width: size,
                  height: size,
                )
              : iconWidget,
        ),
      ),
    );

    final rtl = this.rtl ?? Directionality.of(context) == TextDirection.rtl;

    final rotated = rotateIfRtl && rtl
        ? Transform.rotate(angle: pi, child: result)
        : result;

    return margin != null ? Padding(padding: margin, child: rotated) : rotated;
  }
}
