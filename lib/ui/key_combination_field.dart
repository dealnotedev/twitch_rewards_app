import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:twitch_listener/ui/themes.dart';

class KeyCombinationField extends StatelessWidget {
  final Iterable<String> keys;
  final String placeholder;
  final bool recording;
  final Widget? trailing;

  const KeyCombinationField({
    super.key,
    required this.keys,
    required this.placeholder,
    this.recording = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = keys.isEmpty
        ? TextSpan(text: placeholder)
        : TextSpan(
            children: [
              for (final (index, key) in keys.indexed) ...[
                if (index > 0) const TextSpan(text: ' + '),
                TextSpan(
                  text: key,
                  style: TextStyle(
                    color: theme.textColorPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: theme.inputBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: recording ? theme.accentColor : theme.border,
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: theme.textColorSecondary),
            ),
          ),
          if (trailing != null) ...[const Gap(8), trailing!],
        ],
      ),
    );
  }
}
