import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:twitch_listener/reward.dart';
import 'package:twitch_listener/reward_widget.dart';
import 'package:twitch_listener/themes.dart';

class EnableFilterWidget extends StatefulWidget {
  final SaveHook saveHook;
  final RewardAction action;

  const EnableFilterWidget(
      {super.key, required this.saveHook, required this.action});

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<EnableFilterWidget> {
  late bool _enable;

  @override
  void initState() {
    _enable = widget.action.enable;

    _sourceNameController =
        TextEditingController(text: widget.action.sourceName);
    _filterNameController =
        TextEditingController(text: widget.action.filterName);
    widget.saveHook.addHandler(_handleSave);
    super.initState();
  }

  @override
  void dispose() {
    _sourceNameController.dispose();
    _filterNameController.dispose();
    widget.saveHook.removeHandler(_handleSave);
    super.dispose();
  }

  late final TextEditingController _sourceNameController;
  late final TextEditingController _filterNameController;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Text(
          'Enable filter',
          style: TextStyle(color: Colors.white),
        ),
        const Gap(16),
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
        Expanded(
          child: TextFormField(
            maxLines: 1,
            controller: _filterNameController,
            style: const TextStyle(
              fontSize: 14,
            ),
            decoration: const DefaultInputDecoration(hintText: 'Filter name'),
          ),
        ),
        const Gap(8),
        Switch(value: _enable, onChanged: _handleEnableCheck)
      ])
    ]);
  }

  @override
  void didUpdateWidget(covariant EnableFilterWidget oldWidget) {
    if (widget.saveHook != oldWidget.saveHook) {
      oldWidget.saveHook.removeHandler(_handleSave);
      widget.saveHook.addHandler(_handleSave);
    }
    super.didUpdateWidget(oldWidget);
  }

  void _handleSave() {
    widget.action.enable = _enable;
    widget.action.filterName = _filterNameController.text.trim();
    widget.action.sourceName = _sourceNameController.text.trim();
  }

  void _handleEnableCheck(bool value) {
    setState(() {
      _enable = value;
    });
  }
}
