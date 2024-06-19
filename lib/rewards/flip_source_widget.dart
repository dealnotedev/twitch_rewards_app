import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:twitch_listener/reward.dart';
import 'package:twitch_listener/reward_widget.dart';
import 'package:twitch_listener/themes.dart';

class FlipSceneWidget extends StatefulWidget {
  final SaveHook saveHook;
  final RewardAction action;

  const FlipSceneWidget(
      {super.key, required this.saveHook, required this.action});

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<FlipSceneWidget> {
  late bool _horizontal;
  late bool _vertical;

  @override
  void initState() {
    _horizontal = widget.action.horizontal;
    _vertical = widget.action.vertical;

    _sceneNameController = TextEditingController(text: widget.action.sceneName);
    _sourceNameController =
        TextEditingController(text: widget.action.sourceName);
    widget.saveHook.addHandler(_handleSave);
    super.initState();
  }

  @override
  void dispose() {
    _sceneNameController.dispose();
    _sourceNameController.dispose();
    widget.saveHook.removeHandler(_handleSave);
    super.dispose();
  }

  late final TextEditingController _sceneNameController;
  late final TextEditingController _sourceNameController;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Text(
          'Flip source',
          style: TextStyle(color: Colors.white),
        ),
        const Gap(16),
        Expanded(
          child: TextFormField(
            maxLines: 1,
            controller: _sceneNameController,
            style: const TextStyle(
              fontSize: 14,
            ),
            decoration: const DefaultInputDecoration(hintText: 'Scene name'),
          ),
        ),
        const Gap(8),
        Expanded(
          child: TextFormField(
            maxLines: 1,
            controller: _sourceNameController,
            style: const TextStyle(
              fontSize: 14,
            ),
            decoration: const DefaultInputDecoration(hintText: 'Source name'),
          ),
        ),
        const Gap(8),
        const Text('X'),
        Checkbox(value: _horizontal, onChanged: _handleHorizontalCheck),
        const Text('Y'),
        Checkbox(value: _vertical, onChanged: _handleVerticalCheck),
      ])
    ]);
  }

  @override
  void didUpdateWidget(covariant FlipSceneWidget oldWidget) {
    if (widget.saveHook != oldWidget.saveHook) {
      oldWidget.saveHook.removeHandler(_handleSave);
      widget.saveHook.addHandler(_handleSave);
    }
    super.didUpdateWidget(oldWidget);
  }

  void _handleSave() {
    widget.action.horizontal = _horizontal;
    widget.action.vertical = _vertical;
    widget.action.sceneName = _sceneNameController.text.trim();
    widget.action.sourceName = _sourceNameController.text.trim();
  }

  void _handleHorizontalCheck(bool? value) {
    setState(() {
      _horizontal = (value ?? false);
    });
  }

  void _handleVerticalCheck(bool? value) {
    setState(() {
      _vertical = (value ?? false);
    });
  }
}
