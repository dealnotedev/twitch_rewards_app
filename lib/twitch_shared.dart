import 'package:twitch_listener/observable_value.dart';
import 'package:twitch_listener/twitch/dto.dart';

class TwitchShared {
  final redemptions = ObservableValue<Map<String, RedemptionDto>>(current: {});

  int? getCost(String rewardTitle) {
    return redemptions.current[rewardTitle]?.cost;
  }
}
