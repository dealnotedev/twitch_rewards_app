import 'package:flutter/material.dart';
import 'package:twitch_listener/flutter_switch.dart';
import 'package:twitch_listener/themes.dart';

class CustomSwitch extends StatelessWidget {

  final ThemeData theme;
  final ValueChanged<bool> onToggle;
  final bool value;

  const CustomSwitch({super.key, required this.onToggle, required this.value, required this.theme});

  @override
  Widget build(BuildContext context) {
    final Color thumbColor;

    final Color activeColor;
    final Color inactiveColor;

    if(theme.dark){
      activeColor = const Color(0xFFEEEEEE);
      inactiveColor = const Color(0xFF252525);
      thumbColor = value ? const Color(0xFF121212) : const Color(0xFFEEEEEE);
    } else {
      activeColor = const Color(0xFF030213);
      inactiveColor = const Color(0xFFCBCED4);
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
        value: value, onToggle: onToggle);
  }
}