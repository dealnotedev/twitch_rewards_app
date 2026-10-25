import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SimpleIcon extends StatelessWidget {
  final String icon;
  final String? iconRtl;
  final bool? rtl;

  final double? height;
  final double? width;

  final Color? color;

  final bool rotateIfRtl;

  const SimpleIcon(
      {super.key,
      required this.icon,
      this.iconRtl,
      this.rtl,
      this.rotateIfRtl = false,
      this.height,
      this.width,
      this.color});

  static SimpleIcon simpleSquare(String icon,
      {required double size, Color? color}) {
    return SimpleIcon(
      icon: icon,
      width: size,
      height: size,
      color: color,
    );
  }

  @override
  Widget build(BuildContext context) {
    final iconRtl = this.iconRtl;
    final rtl = this.rtl ?? Directionality.of(context) == TextDirection.rtl;

    final displayedIcon = iconRtl != null && rtl ? iconRtl : icon;

    if (rotateIfRtl && rtl) {
      return Transform.rotate(angle: pi, child: _buildInternal(displayedIcon));
    }

    return _buildInternal(displayedIcon);
  }

  Widget _buildInternal(String icon) {
    final color = this.color;
    if (icon.endsWith('.svg')) {
      return SvgPicture.asset(icon,
          width: width,
          height: height,
          colorFilter:
              color != null ? ColorFilter.mode(color, BlendMode.srcIn) : null);
    } else {
      return Image.asset(
        icon,
        width: width,
        height: height,
        color: color,
      );
    }
  }
}
