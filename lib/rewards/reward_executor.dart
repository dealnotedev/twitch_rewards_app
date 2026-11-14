import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:twitch_listener/audio/audioplayer.dart';
import 'package:twitch_listener/music/music_requests.dart';
import 'package:twitch_listener/obs/obs_connect.dart';
import 'package:twitch_listener/points/viewer_balances_store.dart';
import 'package:twitch_listener/rewards/reward.dart';
import 'package:twitch_listener/rewards/reward_execution.dart';
import 'package:twitch_listener/utils/input_sender.dart';
import 'package:twitch_listener/utils/process_finder.dart';
import 'package:win32/win32.dart' as win32;

class RewardExecutor {
  final Audioplayer audioplayer;
  final ObsConnect obs;
  final MusicRequestManager musicRequests;
  final ViewerBalancesStore? viewerBalances;
  final _audioShuffles = Expando<_AudioShuffle>();

  RewardExecutor({
    required this.audioplayer,
    required this.obs,
    required this.musicRequests,
    this.viewerBalances,
  });

  Future<void> execute(
    Reward reward, {
    String? userInput,
    String requester = '',
    String? requesterId,
    String? requesterLogin,
    int? rewardCost,
    RewardExecution? execution,
  }) async {
    for (var action in reward.handlers) {
      if (execution?.canceled == true) return;
      if (action.disabled) continue;
      if (execution != null) _validateAction(action);
      switch (action.type) {
        case RewardAction.typeCreditPoints:
          final balances = viewerBalances;
          if (balances == null) throw StateError('Viewer balances unavailable');
          if (requesterId == null || requesterId.trim().isEmpty) {
            throw StateError('A Twitch viewer ID is required to credit points');
          }
          final amount = action.pointsAmount ?? rewardCost;
          if (amount == null) {
            throw StateError(
              'Set a points amount for triggers without a reward',
            );
          }
          await balances.credit(
            requesterId,
            amount,
            username: requesterLogin,
            displayName: requester.isEmpty ? null : requester,
          );
          break;

        case RewardAction.typeQueueTrack:
          if (execution == null) {
            musicRequests.enqueue(userInput, requester: requester);
          } else {
            final ticket = musicRequests.enqueueTracked(
              userInput,
              requester: requester,
            );
            if (ticket == null) throw StateError('Music request rejected');
            execution.track(
              ticket.completed.then((outcome) {
                if (outcome != MusicRequestOutcome.completed) {
                  throw StateError('Music request ${outcome.name}');
                }
              }),
              cancel: () async {
                await musicRequests.cancelRequest(ticket.id);
              },
            );
          }
          break;

        case RewardAction.typeDelay:
          await Future.delayed(Duration(milliseconds: action.millis));
          break;

        case RewardAction.typeEnableInput:
          await obs.enableInput(
            inputName: action.inputName ?? '',
            enabled: action.enable,
          );
          break;

        case RewardAction.typeToggleFilter:
          final sourceName = action.sourceName;
          final filterName = action.filterName;

          if (sourceName != null &&
              sourceName.isNotEmpty &&
              filterName != null &&
              filterName.isNotEmpty) {
            switch (action.action) {
              case 'enable':
              case 'disable':
                await obs.enableSourceFilter(
                  sourceName: sourceName,
                  filterName: filterName,
                  enabled: action.action == 'enable',
                );
                break;
              case 'toggle':
                await obs.invertSourceFilter(
                  sourceName: sourceName,
                  filterName: filterName,
                );
                break;
            }
          }
          break;

        case RewardAction.typeEnableFilter:
          final sourceName = action.sourceName;
          final filterName = action.filterName;

          if (sourceName != null &&
              sourceName.isNotEmpty &&
              filterName != null &&
              filterName.isNotEmpty) {
            await obs.enableSourceFilter(
              sourceName: sourceName,
              filterName: filterName,
              enabled: action.enable,
            );
          }
          break;

        case RewardAction.typeFlipSource:
          final sourceName = action.sourceName;
          final sceneName = action.sceneName;

          if (sourceName != null &&
              sourceName.isNotEmpty &&
              sceneName != null &&
              sceneName.isNotEmpty) {
            await obs.flipSource(
              rootSceneName: sceneName,
              sourceName: sourceName,
              horizontal: action.horizontal,
              vertical: action.vertical,
            );
          }
          break;

        case RewardAction.typeInvertFilter:
          final sourceName = action.sourceName;
          final filterName = action.filterName;

          if (sourceName != null &&
              sourceName.isNotEmpty &&
              filterName != null &&
              filterName.isNotEmpty) {
            await obs.invertSourceFilter(
              sourceName: sourceName,
              filterName: filterName,
            );
          }
          break;

        case RewardAction.typeSetScene:
          final sceneNames = action.targets;
          if (sceneNames.isNotEmpty) {
            await obs.enableScene(sceneNames: sceneNames);
          }
          break;

        case RewardAction.typeCrashProcess:
          final target = action.target;
          if (target != null) {
            final effect = compute(_crashProcess, target);
            if (execution != null) {
              execution.track(effect);
            } else {
              await effect;
            }
          }
          break;

        case RewardAction.typeToggleSource:
          final sourceName = action.sourceName;
          final sceneName = action.sceneName;

          if (sourceName != null &&
              sourceName.isNotEmpty &&
              sceneName != null &&
              sceneName.isNotEmpty) {
            switch (action.action) {
              case 'enable':
              case 'disable':
                await obs.enableSource(
                  sceneName: sceneName,
                  sourceName: sourceName,
                  enabled: action.action == 'enable',
                );
                break;

              case 'toggle':
              default:
                await obs.toggleSource(
                  sceneName: sceneName,
                  sourceName: sourceName,
                );
                break;
            }
          }
          break;

        case RewardAction.typeSendInput:
          final inputs = action.inputs;
          if (inputs.isNotEmpty) {
            InputSender.sendInputs(inputs);
          }
          break;

        case RewardAction.typeEnableSource:
          final sourceName = action.sourceName;
          final sceneName = action.sceneName;

          if (sourceName != null &&
              sourceName.isNotEmpty &&
              sceneName != null &&
              sceneName.isNotEmpty) {
            await obs.enableSource(
              sceneName: sceneName,
              sourceName: sourceName,
              enabled: action.enable,
            );
          }
          break;

        case RewardAction.typePlayAudio:
          final filePath = action.filePath;

          if (filePath != null && filePath.isNotEmpty) {
            final effect = audioplayer.playFileWaitCompletion(
              filePath,
              volume: action.volume,
              title: reward.name,
            );
            if (execution != null) {
              execution.track(effect);
            } else {
              effect.catchError((Object _) {});
            }
          }
          break;

        case RewardAction.typePlayAudios:
          if (action.awaitCompletion) {
            await _playAudios(action, title: reward.name);
          } else {
            final effect = _playAudios(action, title: reward.name);
            if (execution != null) {
              execution.track(effect);
            } else {
              effect.catchError((Object _) {});
            }
          }
          break;
      }
    }
  }

  static void _crashProcess(String processName) {
    ProcessFinder.initialize();
    try {
      final processId = ProcessFinder.listRunningProcesses()
          .where((element) {
            return element.name.trim() == processName;
          })
          .firstOrNull
          ?.processId;

      if (processId == null) {
        throw StateError('Process not found: $processName');
      }
      final handle = win32.OpenProcess(win32.PROCESS_TERMINATE, 0, processId);
      if (handle == 0) throw StateError('Cannot open process: $processName');
      try {
        if (win32.TerminateProcess(handle, 0) == 0) {
          throw StateError('Cannot terminate process: $processName');
        }
      } finally {
        win32.CloseHandle(handle);
      }
    } finally {
      ProcessFinder.uninitialize();
    }
  }

  static void _validateAction(RewardAction action) {
    bool empty(String? value) => value == null || value.trim().isEmpty;
    final invalid = switch (action.type) {
      RewardAction.typeDelay => action.millis < 0,
      RewardAction.typeQueueTrack => false,
      RewardAction.typeCreditPoints =>
        action.pointsAmount != null && action.pointsAmount! < 0,
      RewardAction.typeEnableInput => empty(action.inputName),
      RewardAction.typeToggleFilter =>
        empty(action.sourceName) ||
            empty(action.filterName) ||
            !['enable', 'disable', 'toggle'].contains(action.action),
      RewardAction.typeEnableFilter || RewardAction.typeInvertFilter =>
        empty(action.sourceName) || empty(action.filterName),
      RewardAction.typeFlipSource ||
      RewardAction.typeToggleSource ||
      RewardAction.typeEnableSource =>
        empty(action.sceneName) || empty(action.sourceName),
      RewardAction.typeSetScene =>
        action.targets.isEmpty || action.targets.any(empty),
      RewardAction.typeCrashProcess => empty(action.target),
      RewardAction.typeSendInput => action.inputs.isEmpty,
      RewardAction.typePlayAudio => empty(action.filePath),
      RewardAction.typePlayAudios =>
        action.audios.isEmpty ||
            action.count == 0 ||
            action.audios.any((audio) => empty(audio.path)),
      _ => true,
    };
    if (invalid) throw StateError('Incomplete reaction: ${action.type}');
  }

  Future<void> _playAudios(RewardAction action, {required String title}) async {
    final all = action.audios;
    if (all.isEmpty) return;

    final List<AudioEntry> audios;
    if (action.randomize) {
      final shuffle = _audioShuffles[action] ??= _AudioShuffle();
      audios = shuffle.take(all, action.count);
    } else {
      audios = List.of(all);
    }

    for (int i = 0; i < audios.length; i++) {
      final file = audios[i];

      if (i > 0) {
        await Future.delayed(const Duration(milliseconds: 250));
      }
      await audioplayer.playFileWaitCompletion(
        file.path,
        volume: file.volume,
        title: title,
      );
    }
  }
}

class _AudioShuffle {
  final _random = Random();
  var _order = <String>[];
  var _nextIndex = 0;

  List<AudioEntry> take(List<AudioEntry> audios, int? count) {
    final byPath = <String, AudioEntry>{};
    for (final audio in audios) {
      byPath.putIfAbsent(audio.path, () => audio);
    }

    final length = min(count ?? byPath.length, byPath.length);
    RangeError.checkNotNegative(length, 'count');
    if (length == 0) return [];

    final selected = <String>{};
    if (_order.length != byPath.length || !_order.every(byPath.containsKey)) {
      _startCycle(byPath.keys, selected, length);
    }
    for (var remaining = length; remaining > 0; remaining--) {
      if (_nextIndex == _order.length) {
        _startCycle(byPath.keys, selected, remaining);
      }
      selected.add(_order[_nextIndex++]);
    }
    return [for (final path in selected) byPath[path]!];
  }

  void _startCycle(
    Iterable<String> paths,
    Set<String> selected,
    int remaining,
  ) {
    final previousPath = _nextIndex == 0 ? null : _order[_nextIndex - 1];
    _order = paths.toList()..shuffle(_random);
    _nextIndex = 0;

    if (selected.isNotEmpty) {
      // Fill the rest of this run with sounds it hasn't selected yet.
      final prefix = {
        ..._order.where((path) => !selected.contains(path)).take(remaining),
      };
      final rest = _order.where((path) => !prefix.contains(path)).toList()
        ..shuffle(_random);
      _order = [...prefix, ...rest];
    } else if (_order.length > 1 && _order.first == previousPath) {
      final index = 1 + _random.nextInt(_order.length - 1);
      final first = _order.first;
      _order[0] = _order[index];
      _order[index] = first;
    }
  }
}
