import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:twitch_listener/extensions.dart';
import 'package:twitch_listener/generated/assets.dart';
import 'package:twitch_listener/simple_icon.dart';
import 'package:twitch_listener/themes.dart';

class AppBackButton extends StatelessWidget {
  final ThemeData theme;
  final VoidCallback? onTap;

  const AppBackButton({super.key, required this.theme, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(8);
    final color = onTap == null
        ? theme.textColorDisabled
        : theme.textColorPrimary;
    return Material(
      type: MaterialType.transparency,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SimpleIcon.simpleSquare(
                Assets.assetsIcBackWhite16dp,
                size: 16,
                color: color,
              ),
              const Gap(4),
              Text(
                context.localizations.button_back,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
