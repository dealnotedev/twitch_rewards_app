import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:twitch_listener/ui/buttons.dart';
import 'package:twitch_listener/core/extensions.dart';
import 'package:twitch_listener/generated/assets.dart';
import 'package:twitch_listener/ui/outline_icons.dart';
import 'package:twitch_listener/ui/ripple_icon.dart';
import 'package:twitch_listener/ui/simple_icon.dart';
import 'package:twitch_listener/ui/simple_indicator.dart';
import 'package:twitch_listener/ui/themes.dart';
import 'package:twitch_listener/twitch/rewards_controller.dart';

/// Returns true to refund pending requests, false to confirm, or null to cancel.
class TwitchRewardDeleteDialog extends StatefulWidget {
  final String rewardTitle;
  final Future<TwitchRewardPendingSummary> Function() loadSummary;
  const TwitchRewardDeleteDialog({
    super.key,
    required this.rewardTitle,
    required this.loadSummary,
  });

  @override
  State<TwitchRewardDeleteDialog> createState() =>
      _TwitchRewardDeleteDialogState();
}

class _TwitchRewardDeleteDialogState extends State<TwitchRewardDeleteDialog> {
  late Future<TwitchRewardPendingSummary> _summary;

  @override
  void initState() {
    super.initState();
    _summary = widget.loadSummary();
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<TwitchRewardPendingSummary>(
        future: _summary,
        builder: _buildDialog,
      );

  Widget _buildDialog(
    BuildContext context,
    AsyncSnapshot<TwitchRewardPendingSummary> snapshot,
  ) {
    final theme = Theme.of(context);
    final l10n = context.localizations;
    final noPending =
        snapshot.connectionState == ConnectionState.done &&
        snapshot.data?.count == 0;
    return Dialog(
      backgroundColor: theme.surfaceSecondary,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: theme.border, width: 0.5),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 448),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  SimpleIcon.simpleSquare(
                    Assets.assetsIcDeleteWhite16dp,
                    size: 16,
                    color: theme.textColorPrimary,
                  ),
                  const Gap(8),
                  Expanded(
                    child: Text(
                      l10n.twitch_rewards_delete_title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: theme.textColorPrimary,
                      ),
                    ),
                  ),
                  const Gap(8),
                  Semantics(
                    label: MaterialLocalizations.of(context).closeButtonLabel,
                    button: true,
                    child: RippleIcon(
                      icon: Assets.assetsIcCloseWhite16dp,
                      size: 16,
                      borderRadius: BorderRadius.circular(8),
                      color: theme.textColorPrimary,
                      onTap: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
              const Gap(16),
              Text(
                widget.rewardTitle,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: theme.textColorPrimary,
                ),
              ),
              const Gap(12),
              _buildSummary(context, snapshot),
              const Gap(8),
              Text(
                noPending
                    ? l10n.twitch_rewards_delete_empty_description
                    : l10n.twitch_rewards_delete_description,
                style: TextStyle(fontSize: 12, color: theme.textColorSecondary),
              ),
              const Gap(16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  CustomButton(
                    text: MaterialLocalizations.of(context).cancelButtonLabel,
                    style: CustomButtonStyle.secondary,
                    theme: theme,
                    onTap: () => Navigator.pop(context),
                  ),
                  if (noPending)
                    CustomButton(
                      text: l10n.twitch_rewards_delete,
                      prefixIcon: Assets.assetsIcDeleteWhite16dp,
                      style: CustomButtonStyle.primary,
                      theme: theme,
                      onTap: () => Navigator.pop(context, false),
                    )
                  else ...[
                    CustomButton(
                      text: l10n.twitch_rewards_delete_confirm,
                      prefixIcon: Assets.assetsIcCheckWhite16dp,
                      style: CustomButtonStyle.secondary,
                      theme: theme,
                      onTap: () => Navigator.pop(context, false),
                    ),
                    CustomButton(
                      text: l10n.twitch_rewards_delete_refund,
                      prefixIcon: OutlineIcons.refund,
                      style: CustomButtonStyle.primary,
                      theme: theme,
                      onTap: () => Navigator.pop(context, true),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummary(
    BuildContext context,
    AsyncSnapshot<TwitchRewardPendingSummary> snapshot,
  ) {
    final theme = Theme.of(context);
    final l10n = context.localizations;
    if (snapshot.connectionState != ConnectionState.done) {
      return Row(
        children: [
          SizedBox.square(
            dimension: 12,
            child: CircularProgressIndicator(
              color: theme.accentColor,
              strokeWidth: 1.5,
            ),
          ),
          const Gap(8),
          Expanded(
            child: Text(
              l10n.twitch_rewards_delete_loading,
              style: TextStyle(fontSize: 12, color: theme.textColorSecondary),
            ),
          ),
        ],
      );
    }
    final summary = snapshot.data;
    if (summary == null) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            l10n.twitch_rewards_delete_count_failed,
            style: TextStyle(fontSize: 12, color: theme.textColorSecondary),
          ),
          CustomButton(
            text: l10n.redemption_queue_retry,
            prefixIcon: OutlineIcons.refresh,
            style: CustomButtonStyle.secondary,
            theme: theme,
            onTap: () => setState(() {
              _summary = widget.loadSummary();
            }),
          ),
        ],
      );
    }
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        SimpleIndicator(
          text: l10n.twitch_rewards_delete_pending(summary.count),
          style: IndicatorStyle.neutral,
          theme: theme,
        ),
        SimpleIndicator(
          text: l10n.x_points(summary.points),
          style: IndicatorStyle.outlined,
          theme: theme,
        ),
      ],
    );
  }
}
