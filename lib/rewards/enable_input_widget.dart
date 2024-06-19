import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:twitch_listener/reward.dart';
import 'package:twitch_listener/reward_widget.dart';
import 'package:twitch_listener/themes.dart';

class EnableInputWidget extends StatefulWidget {
  final SaveHook saveHook;
  final RewardAction action;

  const EnableInputWidget(
      {super.key, required this.action, required this.saveHook});

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<EnableInputWidget> {
  late bool _enable;

  @override
  void initState() {
    _enable = widget.action.enable;
    _nameController = TextEditingController(text: widget.action.inputName);
    widget.saveHook.addHandler(_handleSave);
    super.initState();
  }

  @override
  void dispose() {
    _nameController.dispose();
    widget.saveHook.removeHandler(_handleSave);
    super.dispose();
  }

  late final TextEditingController _nameController;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Enable input',
              style: TextStyle(color: Colors.white),
            ),
            const Gap(16),
            Expanded(
              child: TextField(
                maxLines: 1,
                controller: _nameController,
                style: const TextStyle(
                  fontSize: 14,
                ),
                decoration:
                    const DefaultInputDecoration(hintText: 'Input name'),
              ),
            ),
            const Gap(8),
            Switch(value: _enable, onChanged: _handleEnableCheck)
          ],
        )
      ],
    );
  }

  void _handleSave() {
    widget.action.enable = _enable;
    widget.action.inputName = _nameController.text;
  }

  @override
  void didUpdateWidget(covariant EnableInputWidget oldWidget) {
    if (widget.saveHook != oldWidget.saveHook) {
      oldWidget.saveHook.removeHandler(_handleSave);
      widget.saveHook.addHandler(_handleSave);
    }
    super.didUpdateWidget(oldWidget);
  }

  void _handleEnableCheck(bool value) {
    setState(() {
      _enable = value;
    });
  }
}
