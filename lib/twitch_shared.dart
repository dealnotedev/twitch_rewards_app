import 'package:twitch_listener/observable_value.dart';
import 'package:twitch_listener/reward.dart';
import 'package:twitch_listener/twitch/dto.dart';

class TwitchShared {
  String? broadcasterId;
  bool rewardsLoaded = false;
  final redemptions = ObservableValue<Map<String, RedemptionDto>>(current: {});

  void setRewards(
    Iterable<RedemptionDto> rewards, {
    required String broadcasterId,
  }) {
    this.broadcasterId = broadcasterId;
    rewardsLoaded = true;
    redemptions.set({for (final reward in rewards) reward.title: reward});
  }

  void clear() {
    broadcasterId = null;
    rewardsLoaded = false;
    redemptions.set({});
  }

  RedemptionDto? findReward(Reward reward) {
    if (!reward.isLinked) return redemptions.current[reward.name];
    if (broadcasterId != reward.twitchBroadcasterId) return null;
    for (final entry in redemptions.current.values) {
      if (entry.id == reward.twitchRewardId) return entry;
    }
    return null;
  }

  int? getCost(String rewardTitle) {
    return redemptions.current[rewardTitle]?.cost;
  }
}
