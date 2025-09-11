import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:twitch_listener/di/service_locator.dart';
import 'package:twitch_listener/dropdown/dropdown_scope.dart';
import 'package:twitch_listener/obs/obs_state.dart';
import 'package:twitch_listener/reward.dart';
import 'package:twitch_listener/reward_configurator.dart';
import 'package:twitch_listener/rewards_state.dart';
import 'package:twitch_listener/twitch_state.dart';

class ApplicationRouter extends NavigatorObserver {
  final ServiceLocator locator;
  final DropdownManager dropdownManager;

  ApplicationRouter({required this.locator, required this.dropdownManager});

  static const routeRoot = '/';
  static const _routeRewardConfig = '/reward/config';

  static final _changes = StreamController<_RouteChange>.broadcast();
  static Route? _current;

  static String? get current => _current?.settings.name;

  @override
  void didPop(Route route, Route? previousRoute) {
    dropdownManager.clear();
    _changes.add(_RouteChange(current: previousRoute, previous: route));
    _current = previousRoute;
    super.didPop(route, previousRoute);
  }

  @override
  void didPush(Route route, Route? previousRoute) {
    dropdownManager.clear();
    _changes.add(_RouteChange(current: route, previous: previousRoute));
    _current = route;
    super.didPush(route, previousRoute);
  }

  static Future<void> openRewardConfig(BuildContext context,
      {required Reward reward}) {
    return Navigator.pushNamed(context, _routeRewardConfig,
        arguments: _RewardConfigArgs(reward: reward));
  }

  static String? getCurrentRoute(BuildContext context) {
    String? currentPath;
    Navigator.popUntil(context, (route) {
      currentPath = route.settings.name;
      return true;
    });
    return currentPath;
  }

  static void popToRoot(BuildContext context) {
    popTo(context, routeRoot);
  }

  static void popTo(BuildContext context, String? to) {
    Navigator.popUntil(context, (route) {
      return route.settings.name == to;
    });
  }

  RouteFactory get routerFactory {
    return (settings) {
      switch (settings.name) {
        case _routeRewardConfig:
          return MaterialPageRoute(
              settings: settings,
              builder: (context) {
                final args = settings.arguments as _RewardConfigArgs;
                return DropdownScope(
                    manager: dropdownManager,
                    child: RewardConfiguratorWidget(
                      audioplayer: locator.provide(),
                      twitchShared: locator.provide(),
                      executor: locator.provide(),
                      reward: args.reward,
                    ));
              });

        case routeRoot:
          return MaterialPageRoute(builder: (context) {
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
                            twitchShared: locator.provide(),
                            webSocketManager: locator.provide(),
                            settings: locator.provide()),
                      ),
                      const Gap(16),
                      Expanded(
                        child: ObsStateWidget(
                            connect: locator.provide(),
                            settings: locator.provide()),
                      ),
                      const Gap(16),
                    ],
                  ),
                  const Gap(16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: RewardsStateWidget(
                      audioplayer: locator.provide(),
                      twitchShared: locator.provide(),
                      executor: locator.provide(),
                      settings: locator.provide(),
                    ),
                  ),
                  const Gap(16)
                ],
              ),
            );
          });
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
