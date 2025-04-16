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
    final files = _action.targets;

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
          const Gap(8),
          _BorderedContainer(
              padding: const EdgeInsets.only(left: 8),
              children: [
                const Text('Random'),
                Checkbox(
                    value: _action.randomize, onChanged: _handleRandomCheck),
              ]),
          const Gap(8),
          if(_action.randomize) ... [
            _BorderedContainer(
                padding: const EdgeInsets.only(left: 8),
                children: [
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
            const Gap(8),
          ],
          _BorderedContainer(
              padding: const EdgeInsets.only(left: 8),
              children: [
                const Text('Wait completion'),
                Checkbox(
                    value: _action.awaitCompletion,
                    onChanged: _handleAwaitCompletionCheck),
              ])
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

  Widget _createFileWidget(int index, String file) {
    return Row(
      children: [
        const Gap(8),
        Expanded(
            child: Text(
          file,
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
}

class _BorderedContainer extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsets? padding;

  const _BorderedContainer({required this.children, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
              color: const Color(0xFFCBC4CF).withValues(alpha: 0.2), width: 1)),
      child: Row(children: children),
    );
  }
}
