import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:twitch_listener/core/extensions.dart';
import 'package:twitch_listener/core/windows_keyboard.dart';
import 'package:twitch_listener/rewards/reward.dart';
import 'package:twitch_listener/ui/buttons.dart';
import 'package:twitch_listener/ui/key_combination_field.dart';
import 'package:twitch_listener/ui/shortcut_recording_dialog.dart';

class SendInputWidget extends StatefulWidget {
  final RewardAction action;
  final VoidCallback changesCallback;

  const SendInputWidget({
    super.key,
    required this.action,
    required this.changesCallback,
  });

  @override
  State<SendInputWidget> createState() => _SendInputState();
}

class _SendInputState extends State<SendInputWidget> {
  Future<void> _setup() async {
    final action = widget.action;
    final keys = await ShortcutRecordingDialog.show(
      context,
      title: context.localizations.reaction_send_input,
    );
    if (!mounted || keys == null || !identical(action, widget.action)) return;

    setState(() {
      action.inputs = [
        for (final key in keys)
          InputEntry(code: key, type: 0, name: windowsShortcutKeyLabel(key)),
      ];
    });
    widget.changesCallback();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = context.localizations;

    return Row(
      children: [
        Expanded(
          child: KeyCombinationField(
            keys: widget.action.inputs.map((entry) => entry.name),
            placeholder: strings.reaction_send_input_hint_default,
          ),
        ),
        const Gap(8),
        CustomButton(
          text: strings.button_setup,
          style: CustomButtonStyle.secondary,
          theme: theme,
          onTap: _setup,
        ),
      ],
    );
  }
}
