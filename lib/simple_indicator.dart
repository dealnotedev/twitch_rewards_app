import 'package:flutter/material.dart';
import 'package:twitch_listener/themes.dart';

class SimpleIndicator extends StatelessWidget {
  final ThemeData theme;
  final String text;
  final IndicatorStyle style;

  final double fontSize;

  const SimpleIndicator(
      {super.key,
      this.fontSize = 12,
      required this.text,
      required this.theme,
      required this.style});

  @override
  Widget build(BuildContext context) {
    const indicatorPadding = EdgeInsets.symmetric(horizontal: 8, vertical: 2);
    final indicatorStyle =
        TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600);

    final Color textColor;
    final Color color;
    final Border? border;

    switch (style) {
      case IndicatorStyle.bold:
        textColor = theme.textColorPrimaryInverted;
        color = theme.buttonColorPrimary;
        border = null;
        break;

      case IndicatorStyle.outlined:
        textColor = theme.textColorPrimary;
        color = theme.buttonColorSecondary;
        border = Border.all(
            color: theme.dividerColor,
            width: 0.5,
            strokeAlign: BorderSide.strokeAlignOutside);
        break;

      case IndicatorStyle.neutral:
        color = theme.buttonColorAlternative;
        textColor = theme.textColorPrimary;
        border = null;
        break;
    }

    return Container(
      padding: indicatorPadding,
      decoration: BoxDecoration(
          color: color, border: border, borderRadius: BorderRadius.circular(6)),
      child: Text(
        text,
        style: indicatorStyle.copyWith(color: textColor),
      ),
    );
  }
}

enum IndicatorStyle { bold, outlined, neutral }
