import 'dart:async';

import 'package:flutter/material.dart';
import 'package:twitch_listener/app/home_screen.dart';
import 'package:twitch_listener/di/service_locator.dart';
import 'package:twitch_listener/rewards/reward.dart';
import 'package:twitch_listener/rewards/reward_configurator.dart';
import 'package:twitch_listener/twitch/dto.dart';
import 'package:twitch_listener/twitch/reward_catalog.dart';
import 'package:twitch_listener/twitch/reward_editor.dart';
import 'package:twitch_listener/twitch/rewards_controller.dart';

class ApplicationRouter extends NavigatorObserver {
  final ServiceLocator locator;

  ApplicationRouter({required this.locator});

  static const routeRoot = '/';
  static const _routeRewardConfig = '/reward/config';
  static const _routeTwitchRewards = '/reward/twitch';
  static const _routeTwitchRewardEditor = '/reward/twitch/edit';

  static final _changes = StreamController<_RouteChange>.broadcast();
  static Route? _current;

  static String? get current => _current?.settings.name;

  @override
  void didPop(Route route, Route? previousRoute) {
    _changes.add(_RouteChange(current: previousRoute, previous: route));
    _current = previousRoute;
    super.didPop(route, previousRoute);
  }

  @override
  void didPush(Route route, Route? previousRoute) {
    _changes.add(_RouteChange(current: route, previous: previousRoute));
    _current = route;
    super.didPush(route, previousRoute);
  }

  static Future<void> openRewardConfig(
    BuildContext context, {
    required Reward reward,
  }) {
    return Navigator.pushNamed(
      context,
      _routeRewardConfig,
      arguments: _RewardConfigArgs(reward: reward),
    );
  }

  static String? getCurrentRoute(BuildContext context) {
    String? currentPath;
    Navigator.popUntil(context, (route) {
      currentPath = route.settings.name;
      return true;
    });
    return currentPath;
  }

  static Future<TwitchRewardSelection?> openTwitchRewards(
    BuildContext context, {
    required Reward reward,
  }) => Navigator.pushNamed<TwitchRewardSelection>(
    context,
    _routeTwitchRewards,
    arguments: _RewardConfigArgs(reward: reward),
  );

  static Future<RedemptionDto?> openTwitchRewardEditor(
    BuildContext context, {
    RedemptionDto? reward,
  }) => Navigator.pushNamed<RedemptionDto>(
    context,
    _routeTwitchRewardEditor,
    arguments: reward,
  );

  static void popToRoot(BuildContext context) {
    popTo(context, routeRoot);
  }

  static void pop(BuildContext context) {
    Navigator.pop(context);
  }

  static void popTo(BuildContext context, String? to) {
    Navigator.popUntil(context, (route) {
      return route.settings.name == to;
    });
  }

  RouteFactory get routerFactory {
    return (settings) {
      switch (settings.name) {
        case _routeTwitchRewards:
          return MaterialPageRoute<TwitchRewardSelection>(
            settings: settings,
            builder: (_) => TwitchRewardCatalog(
              controller: locator.provide(),
              target: (settings.arguments as _RewardConfigArgs).reward,
            ),
          );
        case _routeTwitchRewardEditor:
          return MaterialPageRoute<RedemptionDto>(
            settings: settings,
            builder: (_) => TwitchRewardEditor(
              controller: locator.provide(),
              reward: settings.arguments as RedemptionDto?,
            ),
          );
        case _routeRewardConfig:
          return MaterialPageRoute(
            settings: settings,
            builder: (context) {
              final args = settings.arguments as _RewardConfigArgs;
              return RewardConfiguratorWidget(
                autosaver: locator.provide(),
                audioplayer: locator.provide(),
                twitchShared: locator.provide(),
                executor: locator.provide(),
                youtubeConnection: locator.provide(),
                musicRequests: locator.provide(),
                reward: args.reward,
              );
            },
          );

        case routeRoot:
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => HomeScreen(
              rewardsController: locator.provide(),
              webSocketManager: locator.provide(),
              settings: locator.provide(),
              obsConnect: locator.provide(),
              updateController: locator.provide(),
              redemptionQueue: locator.provide(),
              autosaver: locator.provide(),
              audioplayer: locator.provide(),
              twitchShared: locator.provide(),
              executor: locator.provide(),
            ),
          );
      }

      return null;
    };
  }
}

class _RewardConfigArgs {
  final Reward reward;

  _RewardConfigArgs({required this.reward});
}

class _RouteChange {
  final Route? current;
  final Route? previous;

  _RouteChange({required this.current, required this.previous});
}
