import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:twitch_listener/dropdown/dropdown_menu.dart';
import 'package:twitch_listener/dropdown/simple_dropdown.dart';
import 'package:twitch_listener/extensions.dart';
import 'package:twitch_listener/reward.dart';
import 'package:twitch_listener/text_field_decoration.dart';
import 'package:twitch_listener/themes.dart';

class EnableInputWidget extends StatefulWidget {
  final RewardAction action;

  const EnableInputWidget({super.key, required this.action});

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<EnableInputWidget> {
  late final RewardAction _action;

  late final TextEditingController _inputNameController;

  final _inputNameFocusNode = FocusNode();

  @override
  void initState() {
    _action = widget.action;
    _inputNameController = TextEditingController(text: _action.inputName);
    _inputNameController.addListener(_handleInputNameEdit);
    super.initState();
  }

  @override
  void dispose() {
    _inputNameController.removeListener(_handleInputNameEdit);
    _inputNameController.dispose();
    _inputNameFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
            child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.localizations.input_name_title,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.textColorPrimary),
            ),
            const Gap(6),
            TextFieldDecoration(
                clearable: false,
                builder: (cntx, decoration, style) {
                  return TextField(
                    controller: _inputNameController,
                    focusNode: _inputNameFocusNode,
                    textInputAction: TextInputAction.done,
                    style: style,
                    decoration: decoration,
                  );
                },
                hint: context.localizations.input_name_hint,
                controller: _inputNameController,
                focusNode: _inputNameFocusNode,
                theme: theme)
          ],
        )),
        const Gap(8),
        Expanded(
            child: SimpleDropdown<bool>(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                theme: theme,
                title: context.localizations.action_title,
                available: [
                  Item(id: true, title: context.localizations.action_enable),
                  Item(id: false, title: context.localizations.action_disable),
                ],
                globalKey: _actionKey,
                selected: _action.enable,
                onSelected: _handleActionSelected))
      ],
    );
  }

  final _actionKey = GlobalKey();

  void _handleActionSelected(bool enabled) {
    setState(() {
      _action.enable = enabled;
    });
  }

  void _handleInputNameEdit() {
    _action.inputName = _inputNameController.text.trim();
  }
}
