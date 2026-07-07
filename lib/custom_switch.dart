import 'package:flutter/material.dart';
import 'package:twitch_listener/flutter_switch.dart';
import 'package:twitch_listener/themes.dart';

class CustomSwitch extends StatelessWidget {
  final ThemeData theme;
  final ValueChanged<bool> onToggle;
  final bool value;

  const CustomSwitch(
      {super.key,
      required this.onToggle,
      required this.value,
      required this.theme});

  @override
  Widget build(BuildContext context) {
    final Color thumbColor;

    final Color activeColor;
    final Color inactiveColor;

    if (theme.dark) {
      activeColor = theme.accentColor;
      inactiveColor = theme.buttonColorAlternative;
      thumbColor = value ? const Color(0xFF111419) : theme.textColorSecondary;
    } else {
      activeColor = theme.accentColor;
      inactiveColor = const Color(0xFFD8DEE8);
      thumbColor = Colors.white;
    }

    return FlutterSwitch(
        height: 16,
        width: 32,
        padding: 2,
        toggleSize: 12,
        toggleColor: thumbColor,
        activeColor: activeColor,
        inactiveColor: inactiveColor,
        value: value,
        onToggle: onToggle);
  }
}
