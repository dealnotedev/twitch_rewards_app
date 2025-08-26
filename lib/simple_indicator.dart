import 'package:flutter/material.dart';
import 'package:twitch_listener/themes.dart';

class SimpleIndicator extends StatelessWidget {
  final ThemeData theme;
  final String text;
  final IndicatorStyle style;

  const SimpleIndicator(
      {super.key,
      required this.text,
      required this.theme,
      required this.style});

  @override
  Widget build(BuildContext context) {
    const indicatorPadding =
        EdgeInsets.only(left: 6, right: 8, top: 3, bottom: 3);
    const indicatorStyle =
        TextStyle(fontSize: 10, fontWeight: FontWeight.w600, height: 1);

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
