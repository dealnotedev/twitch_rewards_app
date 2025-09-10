import 'package:flutter/material.dart';
import 'package:twitch_listener/themes.dart';

class EmptyWidget extends StatelessWidget {

  final String text;
  final ThemeData theme;

  final EdgeInsets margin;

  const EmptyWidget({super.key, required this.text, required this.theme, this.margin = EdgeInsets.zero});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      width: double.infinity,
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor, width: 0.5)),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, color: theme.textColorSecondary),
      ),
    );
  }
}