import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:twitch_listener/core/extensions.dart';
import 'package:twitch_listener/core/observable_value.dart';
import 'package:twitch_listener/generated/assets.dart';
import 'package:twitch_listener/twitch/ws_manager.dart';
import 'package:twitch_listener/ui/simple_icon.dart';
import 'package:twitch_listener/ui/themes.dart';

class EventSubPermissionNotice extends StatelessWidget {
  final ObservableValue<Set<TwitchEventType>> reauthorizationRequired;
  final TwitchEventType type;

  const EventSubPermissionNotice({
    super.key,
    required this.reauthorizationRequired,
    required this.type,
  });

  @override
  Widget build(BuildContext context) => StreamBuilder<Set<TwitchEventType>>(
    stream: reauthorizationRequired.value,
    initialData: reauthorizationRequired.current,
    builder: (context, snapshot) {
      final requiredEvents = snapshot.requireData;
      if (!requiredEvents.contains(type)) return const SizedBox.shrink();
      final theme = Theme.of(context);
      final l10n = context.localizations;
      final event = switch (type) {
        TwitchEventType.raid => l10n.reward_trigger_raid,
        TwitchEventType.follow => l10n.reward_trigger_follow,
      };
      final color = theme.dark
          ? const Color(0xFFE8BD76)
          : const Color(0xFF95620B);
      return Semantics(
        liveRegion: true,
        child: Container(
          key: const ValueKey('twitch-events-permission-warning'),
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            border: Border.all(color: color.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SimpleIcon.simpleSquare(
                Assets.assetsIcWarningWhite16dp,
                size: 16,
                color: color,
              ),
              const Gap(8),
              Expanded(
                child: Text(
                  l10n.twitch_events_relogin_warning(event),
                  style: TextStyle(fontSize: 12, color: color),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
