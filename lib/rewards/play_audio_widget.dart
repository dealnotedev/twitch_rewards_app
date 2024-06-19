import 'package:filepicker_windows/filepicker_windows.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:twitch_listener/reward.dart';
import 'package:twitch_listener/reward_widget.dart';
import 'package:twitch_listener/themes.dart';

class PlayAudioWidget extends StatefulWidget {
  final SaveHook saveHook;
  final RewardAction action;

  const PlayAudioWidget(
      {super.key, required this.saveHook, required this.action});

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<PlayAudioWidget> {
  @override
  void initState() {
    _pathController = TextEditingController(text: widget.action.filePath);
    widget.saveHook.addHandler(_handleSave);
    super.initState();
  }

  @override
  void dispose() {
    _pathController.dispose();
    widget.saveHook.removeHandler(_handleSave);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Text(
          'Play audio',
          style: TextStyle(color: Colors.white),
        ),
        const Gap(16),
        Expanded(
          child: TextFormField(
            maxLines: 1,
            controller: _pathController,
            style: const TextStyle(
              fontSize: 14,
            ),
            decoration:
                const DefaultInputDecoration(hintText: 'File path, .wav only'),
          ),
        ),
        const Gap(8),
        ElevatedButton(onPressed: _selectFile, child: const Text('Select'))
      ])
    ]);
  }

  late final TextEditingController _pathController;

  void _selectFile() {
    final file = OpenFilePicker()
      ..filterSpecification = {
        'Audio File (*.wav)': '*.wav',
      }
      ..defaultFilterIndex = 0
      ..defaultExtension = 'wav'
      ..title = 'Select audio file';

    final result = file.getFile();
    if (result != null) {
      _pathController.text = result.path;
    }
  }

  @override
  void didUpdateWidget(covariant PlayAudioWidget oldWidget) {
    if (widget.saveHook != oldWidget.saveHook) {
      oldWidget.saveHook.removeHandler(_handleSave);
      widget.saveHook.addHandler(_handleSave);
    }
    super.didUpdateWidget(oldWidget);
  }

  void _handleSave() {
    widget.action.filePath = _pathController.text;
  }
}
