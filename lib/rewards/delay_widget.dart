import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:twitch_listener/reward.dart';
import 'package:twitch_listener/reward_widget.dart';
import 'package:twitch_listener/themes.dart';

class DelayWidget extends StatefulWidget {
  final SaveHook saveHook;
  final RewardAction action;

  const DelayWidget({super.key, required this.saveHook, required this.action});

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<DelayWidget> {
  late final TextEditingController _durationController;

  @override
  void initState() {
    _durationController =
        TextEditingController(text: widget.action.duration.toString());
    widget.saveHook.addHandler(_handleSave);
    super.initState();
  }

  @override
  void dispose() {
    _durationController.dispose();
    widget.saveHook.removeHandler(_handleSave);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Delay, sec',
              style: TextStyle(color: Colors.white),
            ),
            const Gap(16),
            Expanded(
              child: TextField(
                maxLines: 1,
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly
                ],
                controller: _durationController,
                style: const TextStyle(
                  fontSize: 14,
                ),
                decoration: const DefaultInputDecoration(hintText: 'Duration'),
              ),
            ),
          ],
        )
      ],
    );
  }

  void _handleSave() {
    try {
      widget.action.duration = int.parse(_durationController.text);
    } catch (_) {
      widget.action.duration = 0;
    }
  }

  @override
  void didUpdateWidget(covariant DelayWidget oldWidget) {
    if (widget.saveHook != oldWidget.saveHook) {
      oldWidget.saveHook.removeHandler(_handleSave);
      widget.saveHook.addHandler(_handleSave);
    }
    super.didUpdateWidget(oldWidget);
  }
}
