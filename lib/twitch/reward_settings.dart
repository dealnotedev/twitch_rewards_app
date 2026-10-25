import 'package:twitch_listener/twitch/dto.dart';

class TwitchRewardSettings {
  final String title;
  final int cost;
  final String prompt;
  final String color;
  final bool inputRequired;
  final bool enabled;
  final bool paused;
  final bool skipRequestQueue;
  final int? cooldownSeconds;
  final int? maxPerStream;
  final int? maxPerUserPerStream;

  const TwitchRewardSettings({
    required this.title,
    required this.cost,
    this.prompt = '',
    this.color = '#6441AD',
    this.inputRequired = false,
    this.enabled = true,
    this.paused = false,
    this.skipRequestQueue = false,
    this.cooldownSeconds,
    this.maxPerStream,
    this.maxPerUserPerStream,
  });

  factory TwitchRewardSettings.fromReward(
    RedemptionDto reward, {
    bool? skipRequestQueue,
  }) => TwitchRewardSettings(
    title: reward.title,
    cost: reward.cost,
    prompt: reward.prompt ?? '',
    color: reward.backgroundColor,
    inputRequired: reward.userInputRequired,
    enabled: reward.enabled,
    paused: reward.paused,
    skipRequestQueue: skipRequestQueue ?? reward.skipRequestQueue,
    cooldownSeconds: reward.cooldownSeconds,
    maxPerStream: reward.maxPerStream,
    maxPerUserPerStream: reward.maxPerUserPerStream,
  );

  Map<String, dynamic> toJson({bool creating = false}) => {
    'title': title,
    'cost': cost,
    'prompt': prompt,
    'background_color': color,
    'is_user_input_required': inputRequired,
    'is_enabled': enabled,
    if (!creating) 'is_paused': paused,
    'should_redemptions_skip_request_queue': skipRequestQueue,
    'is_global_cooldown_enabled': cooldownSeconds != null,
    if (cooldownSeconds != null) 'global_cooldown_seconds': cooldownSeconds,
    'is_max_per_stream_enabled': maxPerStream != null,
    if (maxPerStream != null) 'max_per_stream': maxPerStream,
    'is_max_per_user_per_stream_enabled': maxPerUserPerStream != null,
    if (maxPerUserPerStream != null)
      'max_per_user_per_stream': maxPerUserPerStream,
  };
}
