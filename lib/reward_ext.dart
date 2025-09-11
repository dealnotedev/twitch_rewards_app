import 'package:flutter/material.dart';
import 'package:twitch_listener/extensions.dart';
import 'package:twitch_listener/generated/assets.dart';
import 'package:twitch_listener/reward.dart';

class RewardActionAtts {
  final String type;
  final String title;
  final String icon;

  RewardActionAtts(
      {required this.type, required this.title, required this.icon});

  static RewardActionAtts forType(BuildContext context, String type) {
    switch (type) {
      case RewardAction.typeEnableInput:
        return RewardActionAtts(
            type: type,
            title: context.localizations.reaction_enable_input,
            icon: Assets.assetsIcMicWhite16dp);
      case RewardAction.typeDelay:
        return RewardActionAtts(
            type: type,
            title: context.localizations.reaction_delay,
            icon: Assets.assetsIcClockWhite16dp);
      case RewardAction.typePlayAudio:
        return RewardActionAtts(
            type: type,
            title: context.localizations.reaction_play_audio,
            icon: Assets.assetsIcAudioWhite16dp);
      case RewardAction.typePlayAudios:
        return RewardActionAtts(
            type: type,
            title: context.localizations.reaction_play_audios,
            icon: Assets.assetsIcAudioWhite16dp);
      case RewardAction.typeEnableFilter:
        return RewardActionAtts(
            type: type,
            title: context.localizations.reaction_enable_filter,
            icon: Assets.assetsIcFilterWhite16dp);
      case RewardAction.typeToggleFilter:
        return RewardActionAtts(
            type: type,
            title: context.localizations.reaction_toggle_filter,
            icon: Assets.assetsIcFilterWhite16dp);
      case RewardAction.typeInvertFilter:
        return RewardActionAtts(
            type: type,
            title: context.localizations.reaction_invert_filter,
            icon: Assets.assetsIcFilterWhite16dp);
      case RewardAction.typeFlipSource:
        return RewardActionAtts(
            type: type,
            title: context.localizations.reaction_flip_source,
            icon: Assets.assetsIcFlipWhite16dp);
      case RewardAction.typeEnableSource:
        return RewardActionAtts(
            type: type,
            title: context.localizations.reaction_enable_source,
            icon: Assets.assetsIcToggleWhite16dp);
      case RewardAction.typeToggleSource:
        return RewardActionAtts(
            type: type,
            title: context.localizations.reaction_toggle_source,
            icon: Assets.assetsIcToggleWhite16dp);
      case RewardAction.typeSetScene:
        return RewardActionAtts(
            type: type,
            title: context.localizations.reaction_set_scene,
            icon: Assets.assetsIcNextWhite16dp);
      case RewardAction.typeCrashProcess:
        return RewardActionAtts(
            type: type,
            title: context.localizations.reaction_crash_process,
            icon: Assets.assetsIcSkullWhite16dp);
      case RewardAction.typeSendInput:
        return RewardActionAtts(
            type: type,
            title: context.localizations.reaction_send_input,
            icon: Assets.assetsIcF5White16dp);
    }

    throw StateError('Unsupported type "$type"');
  }
}
