import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:twitch_listener/ui/back_button.dart';
import 'package:twitch_listener/core/extensions.dart';
import 'package:twitch_listener/ui/simple_widgets.dart';
import 'package:twitch_listener/ui/themes.dart';
import 'package:twitch_listener/twitch/rewards_controller.dart';

/// Uses the same parent navigator and content area as Reward Configuration.
class TwitchRewardPage extends StatelessWidget {
  final String title;
  final Widget child;
  final VoidCallback? onBack;
  final List<Widget> actions;

  const TwitchRewardPage({
    super.key,
    required this.title,
    required this.child,
    required this.onBack,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.surfacePrimary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final navigation = Row(
                  children: [
                    AppBackButton(theme: theme, onTap: onBack),
                    const Gap(8),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: theme.textColorPrimary,
                        ),
                      ),
                    ),
                  ],
                );
                if (actions.isEmpty) return navigation;
                final buttons = Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: actions,
                );
                final scale = MediaQuery.textScalerOf(context).scale(1);
                if (constraints.maxWidth >= 520 * scale) {
                  return Row(
                    children: [
                      Expanded(child: navigation),
                      const Gap(8),
                      buttons,
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    navigation,
                    const Gap(8),
                    Align(alignment: Alignment.centerRight, child: buttons),
                  ],
                );
              },
            ),
          ),
          SimpleDivider(theme: theme),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

String twitchRewardsErrorMessage(
  BuildContext context,
  TwitchRewardsError error,
) {
  final l10n = context.localizations;
  return switch (error) {
    TwitchRewardsError.notConnected => l10n.twitch_rewards_error_connection,
    TwitchRewardsError.authorization => l10n.twitch_rewards_error_auth,
    TwitchRewardsError.forbidden => l10n.twitch_rewards_error_forbidden,
    TwitchRewardsError.notFound => l10n.twitch_rewards_error_missing,
    TwitchRewardsError.invalid => l10n.twitch_rewards_error_invalid,
    TwitchRewardsError.rateLimited => l10n.twitch_rewards_error_rate,
    TwitchRewardsError.network => l10n.twitch_rewards_error_network,
    TwitchRewardsError.accountChanged => l10n.twitch_rewards_error_account,
    TwitchRewardsError.redemptionChanged =>
      l10n.twitch_rewards_error_redemption_changed,
    TwitchRewardsError.unknown => l10n.twitch_rewards_error_unknown,
  };
}
