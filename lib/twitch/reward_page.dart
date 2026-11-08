import 'package:flutter/material.dart';
import 'package:twitch_listener/core/extensions.dart';
import 'package:twitch_listener/ui/app_page.dart';
import 'package:twitch_listener/twitch/rewards_controller.dart';

/// Uses the same parent navigator and content area as Reward Configuration.
class TwitchRewardPage extends AppPage {
  const TwitchRewardPage({
    super.key,
    required super.title,
    required super.child,
    required super.onBack,
    super.actions,
  });
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
