import 'package:flutter/material.dart';
import 'package:twitch_listener/ui/buttons.dart';
import 'package:twitch_listener/core/extensions.dart';
import 'package:twitch_listener/generated/assets.dart';
import 'package:twitch_listener/ui/ripple_icon.dart';
import 'package:twitch_listener/ui/themes.dart';

import 'update_controller.dart';

class UpdateNotice extends StatelessWidget {
  const UpdateNotice({required this.controller, super.key});

  final UpdateController controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final version = controller.version;
      if (version == null || controller.dismissed) {
        return const SizedBox.shrink();
      }
      final theme = Theme.of(context);
      final strings = context.localizations;
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: theme.cardDecoration,
          child: Row(
            children: [
              Icon(
                Icons.system_update_alt_rounded,
                size: 20,
                color: theme.accentColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.updateAvailable(version),
                      style: TextStyle(
                        color: theme.textColorPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      controller.launchFailed
                          ? strings.updateLaunchFailed
                          : strings.updateNoticeDetail,
                      style: TextStyle(
                        color: theme.textColorSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              CustomButton(
                text: strings.updateOpen,
                style: CustomButtonStyle.primary,
                theme: theme,
                loading: controller.opening,
                onTap: controller.opening
                    ? null
                    : () => controller.open(
                        locale: Localizations.localeOf(context).toLanguageTag(),
                        brightness: theme.brightness,
                      ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: strings.updateDismiss,
                child: RippleIcon(
                  borderRadius: BorderRadius.circular(8),
                  icon: Assets.assetsIcCloseWhite16dp,
                  onTap: controller.opening ? null : controller.dismiss,
                  size: 16,
                  color: theme.textColorPrimary,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
