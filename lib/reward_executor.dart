import 'package:flutter/foundation.dart';
import 'package:twitch_listener/audioplayer.dart';
import 'package:twitch_listener/music/music_requests.dart';
import 'package:twitch_listener/obs/obs_connect.dart';
import 'package:twitch_listener/reward.dart';
import 'package:twitch_listener/reward_execution.dart';
import 'package:twitch_listener/utils/input_sender.dart';
import 'package:twitch_listener/utils/process_finder.dart';
import 'package:win32/win32.dart' as win32;

class RewardExecutor {
  final Audioplayer audioplayer;
  final ObsConnect obs;
  final MusicRequestManager musicRequests;

  RewardExecutor({
    required this.audioplayer,
    required this.obs,
    required this.musicRequests,
  });

  Future<void> execute(
    Reward reward, {
    String? userInput,
    String requester = '',
    RewardExecution? execution,
  }) async {
    for (var action in reward.handlers) {
      if (execution?.canceled == true) return;
      if (action.disabled) continue;
      if (execution != null) _validateAction(action);
      switch (action.type) {
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
            await _playAudios(action, title: reward.name, userInput: userInput);
          } else {
            final effect = _playAudios(
              action,
              title: reward.name,
              userInput: userInput,
            );
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

  static int _stableRandomFromText(String text, int max) {
    if (max <= 0) {
      throw ArgumentError('max must be > 0');
    }

    final hash = _fnv1a32(text);

    final positive = hash & 0x7fffffff;
    return positive % max;
  }

  static int _fnv1a32(String input) {
    const int fnvPrime = 0x01000193;
    int hash = 0x811c9dc5;

    for (final codeUnit in input.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * fnvPrime) & 0xffffffff;
    }

    return hash;
  }

  Future<void> _playAudios(
    RewardAction action, {
    required String title,
    required String? userInput,
  }) async {
    final all = List.of(action.audios);
    final count = action.count;

    if (all.isEmpty) return;

    final List<AudioEntry> audios;

    if (action.randomize &&
        count == 1 &&
        userInput != null &&
        userInput.isNotEmpty) {
      final index = _stableRandomFromText(userInput, all.length);
      audios = [all[index]];
    } else if (action.randomize) {
      all.shuffle();

      if (count != null) {
        audios = all.take(count).toList();
      } else {
        audios = all;
      }
    } else {
      audios = all;
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
