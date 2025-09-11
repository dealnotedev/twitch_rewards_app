import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:twitch_listener/extensions.dart';
import 'package:twitch_listener/reward.dart';
import 'package:twitch_listener/text_field_decoration.dart';

class DelayWidget extends StatefulWidget {
  final RewardAction action;

  const DelayWidget({super.key, required this.action});

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<DelayWidget> {
  late final RewardAction _action;

  late final TextEditingController _secondsController;

  final _secondsFocusNode = FocusNode();

  @override
  void initState() {
    _action = widget.action;
    _secondsController =
        TextEditingController(text: widget.action.duration.toString());
    _secondsController.addListener(_handleSecondsEdit);
    super.initState();
  }

  @override
  void dispose() {
    _secondsController.removeListener(_handleSecondsEdit);
    _secondsController.dispose();
    _secondsFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TextFieldDecoration(
        clearable: false,
        builder: (cntx, decoration, style) {
          return TextField(
            controller: _secondsController,
            focusNode: _secondsFocusNode,
            maxLines: 1,
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly
            ],
            textInputAction: TextInputAction.search,
            style: style,
            decoration: decoration,
          );
        },
        hint: context.localizations.reaction_delay_seconds_hint,
        controller: _secondsController,
        focusNode: _secondsFocusNode,
        theme: theme);
  }

  void _handleSecondsEdit() {
    try {
      _action.duration = int.parse(_secondsController.text.trim());
    } catch (_) {}
  }
}
