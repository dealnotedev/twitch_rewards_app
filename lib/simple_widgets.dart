import 'package:flutter/material.dart';

class SimpleDivider extends StatelessWidget {
  final double? indent;
  final double? endIndent;
  final ThemeData theme;
  final double height;
  final Color? color;

  const SimpleDivider(
      {super.key,
      required this.theme,
      this.indent,
      this.color,
      this.endIndent,
      this.height = 0.5});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: height,
      endIndent: endIndent,
      indent: indent,
      thickness: height,
      color: color ?? theme.dividerColor,
    );
  }
}
