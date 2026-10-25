import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:twitch_listener/audio/audioplayer.dart';
import 'package:twitch_listener/core/autosaver.dart';
import 'package:twitch_listener/core/settings.dart';
import 'package:twitch_listener/obs/obs_connect.dart';
import 'package:twitch_listener/obs/obs_state.dart';
import 'package:twitch_listener/rewards/reward_executor.dart';
import 'package:twitch_listener/rewards/rewards_state.dart';
import 'package:twitch_listener/twitch/redemption_queue_controller.dart';
import 'package:twitch_listener/twitch/redemption_queue_panel.dart';
import 'package:twitch_listener/twitch/rewards_controller.dart';
import 'package:twitch_listener/twitch/twitch_shared.dart';
import 'package:twitch_listener/twitch/twitch_state.dart';
import 'package:twitch_listener/twitch/ws_manager.dart';
import 'package:twitch_listener/updates/update_controller.dart';
import 'package:twitch_listener/updates/update_notice.dart';

class HomeScreen extends StatelessWidget {
  final TwitchRewardsController rewardsController;
  final WebSocketManager webSocketManager;
  final Settings settings;
  final ObsConnect obsConnect;
  final UpdateController updateController;
  final RedemptionQueueController redemptionQueue;
  final Autosaver autosaver;
  final Audioplayer audioplayer;
  final TwitchShared twitchShared;
  final RewardExecutor executor;

  const HomeScreen({
    super.key,
    required this.rewardsController,
    required this.webSocketManager,
    required this.settings,
    required this.obsConnect,
    required this.updateController,
    required this.redemptionQueue,
    required this.autosaver,
    required this.audioplayer,
    required this.twitchShared,
    required this.executor,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Gap(16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Gap(16),
              Expanded(
                child: TwitchStateWidget(
                  rewardsController: rewardsController,
                  webSocketManager: webSocketManager,
                  settings: settings,
                ),
              ),
              const Gap(16),
              Expanded(
                child: ObsStateWidget(connect: obsConnect, settings: settings),
              ),
              const Gap(16),
            ],
          ),
          const Gap(16),
          UpdateNotice(controller: updateController),
          RedemptionQueuePanel(controller: redemptionQueue),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: RewardsStateWidget(
              rewardsController: rewardsController,
              autosaver: autosaver,
              audioplayer: audioplayer,
              twitchShared: twitchShared,
              executor: executor,
              settings: settings,
            ),
          ),
          const Gap(16),
        ],
      ),
    );
  }
}
