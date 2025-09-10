import 'dart:io';

import 'package:collection/collection.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:twitch_listener/audioplayer.dart';
import 'package:twitch_listener/common_widgets.dart';
import 'package:twitch_listener/reward.dart';
import 'package:twitch_listener/reward_widget.dart';
import 'package:twitch_listener/ripple_icon.dart';

class PlayAudiosWidget extends StatefulWidget {
  final SaveHook saveHook;
  final RewardAction action;
  final Audioplayer audioplayer;

  const PlayAudiosWidget(
      {super.key,
      required this.saveHook,
      required this.action,
      required this.audioplayer});

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<PlayAudiosWidget> {
  late final Audioplayer _audioplayer;
  late final RewardAction _action;

  @override
  void initState() {
    _action = widget.action;
    _audioplayer = widget.audioplayer;
    widget.saveHook.addHandler(_handleSave);
    super.initState();
  }

  @override
  void dispose() {
    _stopVolumePlaying();
    widget.saveHook.removeHandler(_handleSave);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const radius = Radius.circular(4);
    final files = _action.audios;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Gap(8),
      const Text(
        'Play audio',
        style: TextStyle(color: Colors.white),
      ),
      const Gap(8),
      Container(
        decoration: const BoxDecoration(
            color: Color(0xFF272E37),
            borderRadius: BorderRadius.only(topLeft: radius, topRight: radius)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              constraints: const BoxConstraints(minHeight: 38),
              alignment: Alignment.center,
              child: files.isNotEmpty
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: files.mapIndexed((index, file) {
                        return _createFileWidget(index, file);
                      }).toList(),
                    )
                  : const Text(
                      '¯\\_(ツ)_/¯ where is your music?',
                      style: TextStyle(
                          color: Color(0xFFA9ABAF),
                          fontWeight: FontWeight.w600),
                    ),
            ),
            const Divider(color: Color(0xFFCBC4CF), height: 1, thickness: 1)
          ],
        ),
      ),
      const Gap(12),
      Row(
        children: [
          ElevatedButton(onPressed: _selectFile, child: const Text('Add')),
          const Gap(16),
          Row(children: [
            const Text('Wait completion'),
            Checkbox(
                value: _action.awaitCompletion,
                onChanged: _handleAwaitCompletionCheck),
          ]),
          const Gap(8),
          Row(children: [
            const Text('Random'),
            Checkbox(value: _action.randomize, onChanged: _handleRandomCheck),
          ]),
          const Gap(8),
          if (_action.randomize) ...[
            Row(children: [
              const Text('Count'),
              RippleIcon(
                  size: 16,
                  iconWidget: const Icon(
                    Icons.remove,
                    size: 16,
                  ),
                  onTap: _decrementCount),
              Text(
                _action.count?.toString() ?? 'All',
                style: const TextStyle(
                    color: Colors.green, fontWeight: FontWeight.w600),
              ),
              RippleIcon(
                  size: 16,
                  iconWidget: const Icon(
                    Icons.add,
                    size: 16,
                  ),
                  onTap: _incrementCount),
            ]),
          ],
        ],
      )
    ]);
  }

  void _incrementCount() {
    setState(() {
      final count = _action.count;
      if (count == null) {
        _action.count = 1;
      } else {
        _action.count = count + 1;
      }
    });
  }

  void _decrementCount() {
    setState(() {
      final count = _action.count;
      if (count != null && count > 1) {
        _action.count = count - 1;
      } else if (count != null) {
        _action.count = null;
      }
    });
  }

  Widget _createFileWidget(int index, AudioEntry file) {
    return Row(
      children: [
        const Gap(4),
        SizedBox(
          width: 66,
          child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.5),
                  trackHeight: 1.0,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 4)),
              child: Slider(
                  padding: EdgeInsets.zero,
                  max: 3.0,
                  value: file.volume.current,
                  onChangeStart: (v) => _onVolumeStart(file, v),
                  onChangeEnd: (v) => _onVolumeEnd(file, v),
                  onChanged: (v) => _onVolumeChange(file, v))),
        ),
        const Gap(12),
        Expanded(
            child: Text(
          file.path,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              height: 1, fontSize: 13, fontWeight: FontWeight.w400),
        )),
        OnHoverVisibility(
            child: RippleIcon(
                onTap: () {
                  _handleFileDeleteClick(index);
                },
                size: 16,
                padding: 4,
                iconWidget: const Icon(
                  Icons.delete,
                  size: 16,
                )))
      ],
    );
  }

  PlayToken? _playToken;

  void _onVolumeEnd(AudioEntry entry, double value) {
    _stopVolumePlaying();
  }

  void _stopVolumePlaying() {
    final playToken = _playToken;
    _playToken = null;

    if (playToken != null) {
      _audioplayer.cancelByToken(playToken);
    }
  }

  void _onVolumeStart(AudioEntry entry, double value) async {
    _stopVolumePlaying();

    final file = File(entry.path);

    if (file.existsSync()) {
      _playToken = await _audioplayer.playFileInfinitely(file.path,
          volume: entry.volume);
    }
  }

  void _selectFile() async {
    final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Select audio files',
        type: FileType.custom,
        allowedExtensions: ['wav'],
        allowMultiple: true);

    final paths = result?.files
            .where((f) => f.path != null)
            .map((f) => f.path!)
            .toList() ??
        [];

    setState(() {
      _action.audios.addAll(paths.map((p) => AudioEntry(path: p)));
    });
  }

  @override
  void didUpdateWidget(covariant PlayAudiosWidget oldWidget) {
    if (widget.saveHook != oldWidget.saveHook) {
      oldWidget.saveHook.removeHandler(_handleSave);
      widget.saveHook.addHandler(_handleSave);
    }
    super.didUpdateWidget(oldWidget);
  }

  void _handleSave() {}

  void _handleFileDeleteClick(int index) {
    setState(() {
      final removed = _action.audios.removeAt(index);
      removed.dispose();
    });
  }

  void _handleRandomCheck(bool? value) {
    setState(() {
      _action.randomize = value ?? false;
    });
  }

  void _handleAwaitCompletionCheck(bool? value) {
    setState(() {
      _action.awaitCompletion = value ?? false;
    });
  }

  void _onVolumeChange(AudioEntry file, double v) {
    setState(() {
      file.volume.set(v);
    });
  }
}
