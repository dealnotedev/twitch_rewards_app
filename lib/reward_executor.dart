import 'package:flutter/foundation.dart';
import 'package:twitch_listener/audioplayer.dart';
import 'package:twitch_listener/input_sender.dart';
import 'package:twitch_listener/obs/obs_connect.dart';
import 'package:twitch_listener/process_finder.dart';
import 'package:twitch_listener/reward.dart';
import 'package:win32/win32.dart' as win32;

class RewardExecutor {
  final Audioplayer audioplayer;
  final ObsConnect obs;

  RewardExecutor({required this.audioplayer, required this.obs});

  Future<void> execute(Reward reward) async {
    for (var action in reward.handlers) {
      switch (action.type) {
        case RewardAction.typeDelay:
          await Future.delayed(Duration(seconds: action.duration));
          break;

        case RewardAction.typeEnableInput:
          await obs.enableInput(
              inputName: action.inputName ?? '', enabled: action.enable);
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
            await obs.toggleSource(
                sceneName: sceneName, sourceName: sourceName);
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
                enabled: action.enable);
          }
          break;

        case RewardAction.typePlayAudio:
          final filePath = action.filePath;

          if (filePath != null && filePath.isNotEmpty) {
            audioplayer.playFileWaitCompletion(filePath, volume: action.volume);
          }
          break;

        case RewardAction.typePlayAudios:
          if (action.awaitCompletion) {
            await _playAudios(action);
          } else {
            _playAudios(action);
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

  Future<void> _playAudios(RewardAction action) async {
    final all = List.of(action.audios);
    final count = action.count;

    if (all.isEmpty) return;

    final List<AudioEntry> audios;

    if (action.randomize) {
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
      await audioplayer.playFileWaitCompletion(file.path, volume: file.volume);
    }
  }
}
