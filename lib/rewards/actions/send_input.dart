import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:twitch_listener/ui/buttons.dart';
import 'package:twitch_listener/core/extensions.dart';
import 'package:twitch_listener/rewards/reward.dart';
import 'package:twitch_listener/ui/key_combination_field.dart';
import 'package:twitch_listener/ui/themes.dart';
import 'package:twitch_listener/utils/keys_logger.dart';

class SendInputWidget extends StatefulWidget {
  final RewardAction action;
  final VoidCallback changesCallback;

  const SendInputWidget({
    super.key,
    required this.action,
    required this.changesCallback,
  });

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<SendInputWidget> {
  late final RewardAction _action;

  @override
  void initState() {
    _action = widget.action;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: _recording
              ? _KeylogWidget(onCompleted: _handleEntriesRecorded)
              : KeyCombinationField(
                  keys: _action.inputs.map((entry) => entry.name),
                  placeholder:
                      context.localizations.reaction_send_input_hint_default,
                ),
        ),
        const Gap(8),
        CustomButton(
          text: context.localizations.button_setup,
          style: CustomButtonStyle.secondary,
          theme: theme,
          onTap: _recording ? null : () => _handleSetupClick(context),
        ),
      ],
    );
  }

  bool _recording = false;

  void _handleSetupClick(BuildContext context) {
    setState(() {
      _recording = true;
    });
  }

  void _handleEntriesRecorded(Set<InputEntry> entries) {
    setState(() {
      _recording = false;
      _action.inputs = List.of(entries);
      widget.changesCallback();
    });
  }
}

class _KeylogWidget extends StatefulWidget {
  final void Function(Set<InputEntry> entries)? onCompleted;

  const _KeylogWidget({this.onCompleted});

  @override
  State<StatefulWidget> createState() => _KeylogState();
}

class _KeylogState extends State<_KeylogWidget> with TickerProviderStateMixin {
  VoidCallback? _stopLogging;

  AnimationController? _controller;

  @override
  void initState() {
    _stopLogging = KeysLogger.listen(_handleKeyboardEvent);

    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 5))
          ..addListener(_handleAnimationProgress)
          ..addStatusListener(_handleAnimationStatus)
          ..forward();

    super.initState();
  }

  @override
  void dispose() {
    _stopLogging?.call();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return KeyCombinationField(
      keys: _entries.map((entry) => entry.name),
      placeholder: context.localizations.reaction_send_input_hint_recording,
      recording: true,
      trailing: SizedBox.square(
        dimension: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: theme.accentColor,
          value: _controller?.value,
        ),
      ),
    );
  }

  final _entries = <InputEntry>{};

  void _handleKeyboardEvent({required int keyCode, required String keyLabel}) {
    debugPrint('Keyboard $keyCode $keyLabel');

    final entry = InputEntry(code: keyCode, type: 0, name: keyLabel);
    _entries.add(entry);

    setState(() {});
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      widget.onCompleted?.call(_entries);
    }
  }

  void _handleAnimationProgress() {
    setState(() {});
  }
}
