import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:twitch_listener/reward.dart';
import 'package:twitch_listener/reward_widget.dart';
import 'package:twitch_listener/themes.dart';

class ToggleSourceWidget extends StatefulWidget {
  final SaveHook saveHook;
  final RewardAction action;

  const ToggleSourceWidget(
      {super.key, required this.saveHook, required this.action});

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<ToggleSourceWidget> {

  @override
  void initState() {
    _sourceNameController =
        TextEditingController(text: widget.action.sourceName);
    _sceneNameController = TextEditingController(text: widget.action.sceneName);
    widget.saveHook.addHandler(_handleSave);
    super.initState();
  }

  @override
  void dispose() {
    _sourceNameController.dispose();
    _sceneNameController.dispose();
    widget.saveHook.removeHandler(_handleSave);
    super.dispose();
  }

  late final TextEditingController _sourceNameController;
  late final TextEditingController _sceneNameController;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Text(
          'Toggle source',
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
      ])
    ]);
  }

  @override
  void didUpdateWidget(covariant ToggleSourceWidget oldWidget) {
    if (widget.saveHook != oldWidget.saveHook) {
      oldWidget.saveHook.removeHandler(_handleSave);
      widget.saveHook.addHandler(_handleSave);
    }
    super.didUpdateWidget(oldWidget);
  }

  void _handleSave() {
    widget.action.sceneName = _sceneNameController.text.trim();
    widget.action.sourceName = _sourceNameController.text.trim();
  }
}
