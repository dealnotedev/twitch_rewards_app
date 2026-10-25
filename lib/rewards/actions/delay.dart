import 'package:flutter/material.dart';
import 'package:twitch_listener/core/extensions.dart';
import 'package:twitch_listener/ui/integer_input_formatter.dart';
import 'package:twitch_listener/rewards/reward.dart';
import 'package:twitch_listener/ui/text_field_decoration.dart';

class DelayWidget extends StatefulWidget {
  final RewardAction action;
  final VoidCallback changesCallback;

  const DelayWidget(
      {super.key, required this.action, required this.changesCallback});

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<DelayWidget> {
  late final RewardAction _action;

  late final TextEditingController _millisController;

  final _millisFocusNode = FocusNode();
  // Duration stores microseconds in a signed 64-bit integer on the desktop.
  static const _maximumMillis =
      0x7fffffffffffffff ~/ Duration.microsecondsPerMillisecond;

  @override
  void initState() {
    _action = widget.action;
    _millisController =
        TextEditingController(text: widget.action.millis.toString());
    _millisController.addListener(_handleMillisEdit);
    _millisFocusNode.addListener(_handleFocusChanged);
    super.initState();
  }

  @override
  void dispose() {
    _millisController.removeListener(_handleMillisEdit);
    _millisController.dispose();
    _millisFocusNode.removeListener(_handleFocusChanged);
    _millisFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TextFieldDecoration(
        clearable: false,
        builder: (cntx, decoration, style) {
          return TextField(
            controller: _millisController,
            focusNode: _millisFocusNode,
            maxLines: 1,
            keyboardType: const TextInputType.numberWithOptions(
                signed: false, decimal: false),
            inputFormatters: const [
              UnsignedIntegerInputFormatter(maxValue: _maximumMillis)
            ],
            textInputAction: TextInputAction.done,
            autocorrect: false,
            enableSuggestions: false,
            enableIMEPersonalizedLearning: false,
            smartDashesType: SmartDashesType.disabled,
            smartQuotesType: SmartQuotesType.disabled,
            style: style,
            decoration: decoration,
          );
        },
        hint: context.localizations.reaction_delay_seconds_hint,
        controller: _millisController,
        focusNode: _millisFocusNode,
        theme: theme);
  }

  void _handleMillisEdit() {
    final text = _millisController.text;
    final millis = text.isEmpty ? 0 : int.tryParse(text);
    if (millis == null ||
        millis < 0 ||
        millis > _maximumMillis ||
        millis == _action.millis) {
      return;
    }
    _action.millis = millis;
    widget.changesCallback();
  }

  void _handleFocusChanged() {
    if (!_millisFocusNode.hasFocus && _millisController.text.isEmpty) {
      _millisController.text = '0';
    }
  }
}
