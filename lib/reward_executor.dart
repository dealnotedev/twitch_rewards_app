import 'package:flutter/foundation.dart';
import 'package:twitch_listener/audioplayer.dart';
import 'package:twitch_listener/obs/obs_connect.dart';
import 'package:twitch_listener/reward.dart';
import 'package:twitch_listener/utils/input_sender.dart';
import 'package:twitch_listener/utils/process_finder.dart';
import 'package:win32/win32.dart' as win32;

class RewardExecutor {
  final Audioplayer audioplayer;
  final ObsConnect obs;

  RewardExecutor({required this.audioplayer, required this.obs});

  Future<void> execute(Reward reward, {String? userInput}) async {
    for (var action in reward.handlers) {
      switch (action.type) {
        case RewardAction.typeDelay:
          await Future.delayed(Duration(seconds: action.duration));
          break;

        case RewardAction.typeEnableInput:
          await obs.enableInput(
              inputName: action.inputName ?? '', enabled: action.enable);
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
                    enabled: action.action == 'enable');
                break;
              case 'toggle':
                await obs.invertSourceFilter(
                    sourceName: sourceName, filterName: filterName);
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
                enabled: action.enable);
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
                vertical: action.vertical);
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
                sourceName: sourceName, filterName: filterName);
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
            compute(_crashProcess, target);
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
                    enabled: action.action == 'enable');
                break;

              case 'toggle':
              default:
                await obs.toggleSource(
                    sceneName: sceneName, sourceName: sourceName);
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
              sceneName.isNotEmpty) {}
          break;

        case RewardAction.typePlayAudio:
          final filePath = action.filePath;

          if (filePath != null && filePath.isNotEmpty) {
            audioplayer.playFileWaitCompletion(filePath,
                volume: action.volume, title: reward.name);
          }
          break;

        case RewardAction.typePlayAudios:
          if (action.awaitCompletion) {
            await _playAudios(action, title: reward.name, userInput: userInput);
          } else {
            _playAudios(action, title: reward.name, userInput: userInput);
          }
          break;
      }
    }
  }

  static void _crashProcess(String processName) {
    ProcessFinder.initialize();

    final processId = ProcessFinder.listRunningProcesses()
        .where((element) {
          return element.name.trim() == processName;
        })
        .firstOrNull
        ?.processId;

    if (processId != null) {
      final handle = win32.OpenProcess(
          win32.PROCESS_ACCESS_RIGHTS.PROCESS_TERMINATE, 0, processId);

      win32.TerminateProcess(handle, 0);
      win32.CloseHandle(handle);
    }

    ProcessFinder.uninitialize();
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

  Future<void> _playAudios(RewardAction action,
      {required String title, required String? userInput}) async {
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
      await audioplayer.playFileWaitCompletion(file.path,
          volume: file.volume, title: title);
    }
  }
}
