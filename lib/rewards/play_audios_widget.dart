import 'package:collection/collection.dart';
import 'package:filepicker_windows/filepicker_windows.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:twitch_listener/common_widgets.dart';
import 'package:twitch_listener/reward.dart';
import 'package:twitch_listener/reward_widget.dart';
import 'package:twitch_listener/ripple_icon.dart';

class PlayAudiosWidget extends StatefulWidget {
  final SaveHook saveHook;
  final RewardAction action;

  const PlayAudiosWidget(
      {super.key, required this.saveHook, required this.action});

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<PlayAudiosWidget> {
  late final RewardAction _action;

  @override
  void initState() {
    _action = widget.action;
    widget.saveHook.addHandler(_handleSave);
    super.initState();
  }

  @override
  void dispose() {
    widget.saveHook.removeHandler(_handleSave);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const radius = Radius.circular(4);

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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _action.targets.mapIndexed((index, f) {
                  return Row(
                    children: [
                      Expanded(
                          child: Text(
                        f,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            height: 1,
                            fontSize: 13,
                            fontWeight: FontWeight.w400),
                      )),
                      OnHoverVisibility(
                          child: RippleIcon(
                              onTap: () {
                                _handleFileDeleteClick(index);
                              },
                              size: 16,
                              padding: 8,
                              iconWidget: const Icon(
                                Icons.delete,
                                size: 16,
                              )))
                    ],
                  );
                }).toList(),
              ),
            ),
            const Divider(color: Color(0xFFCBC4CF), height: 1, thickness: 1)
          ],
        ),
      ),
      const Gap(8),
      ElevatedButton(onPressed: _selectFile, child: const Text('Add'))
    ]);
  }

  void _selectFile() {
    final file = OpenFilePicker()
      ..filterSpecification = {
        'Audio File (*.wav)': '*.wav',
      }
      ..defaultFilterIndex = 0
      ..defaultExtension = 'wav'
      ..title = 'Select audio files';

    final result = file.getFiles();
    setState(() {
      _action.targets.addAll(result.map((f) => f.path));
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
      _action.targets.removeAt(index);
    });
  }
}
