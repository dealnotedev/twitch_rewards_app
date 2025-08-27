import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:twitch_listener/simple_icon.dart';
import 'package:twitch_listener/themes.dart';

class CustomButton extends StatelessWidget {
  final ThemeData theme;
  final String text;
  final CustomButtonStyle style;
  final bool loading;
  final VoidCallback? onTap;
  final String? prefixIcon;
  final String? suffixIcon;

  const CustomButton(
      {super.key,
      this.prefixIcon,
        this.suffixIcon,
      required this.text,
      required this.style,
      this.loading = false,
      required this.theme,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    final Color color;
    final Color textColor;
    final BoxBorder? border;

    switch (style) {
      case CustomButtonStyle.primary:
        color = theme.buttonColorPrimary;
        textColor = theme.textColorPrimaryInverted;
        border = null;
        break;

      case CustomButtonStyle.secondary:
        color = theme.buttonColorSecondary;
        textColor = theme.textColorPrimary;
        border = Border.all(
            color: theme.dividerColor,
            strokeAlign: BorderSide.strokeAlignOutside,
            width: 0.5);
        break;
    }

    final radius = BorderRadius.circular(6);
    final prefixIcon = this.prefixIcon;
    final suffixIcon = this.suffixIcon;
    return Material(
      color: color.withValues(alpha: onTap != null ? 1.0 : 0.5),
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: border,
            borderRadius: radius,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading) ...[
                SizedBox(
                  height: 10,
                  width: 10,
                  child: CircularProgressIndicator(
                    color:
                        textColor.withValues(alpha: onTap != null ? 1.0 : 0.75),
                    strokeWidth: 1.5,
                  ),
                ),
              ] else if (prefixIcon != null) ...[
                SimpleIcon.simpleSquare(prefixIcon, size: 16, color: textColor),
              ],
              if ((loading || prefixIcon != null) && text.isNotEmpty) ...[
                const Gap(8)
              ],
              Text(
                text,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: textColor.withValues(
                        alpha: onTap != null ? 1.0 : 0.75)),
              ),
              if(suffixIcon != null) ... [
                const Gap(8),
                SimpleIcon.simpleSquare(suffixIcon, size: 16, color: textColor),
              ]
            ],
          ),
        ),
      ),
    );
  }
}

enum CustomButtonStyle { primary, secondary }
