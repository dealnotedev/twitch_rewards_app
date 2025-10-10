import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:twitch_listener/dropdown/dropdown_menu.dart';
import 'package:twitch_listener/dropdown/simple_dropdown.dart';
import 'package:twitch_listener/extensions.dart';
import 'package:twitch_listener/reward.dart';
import 'package:twitch_listener/text_field_decoration.dart';
import 'package:twitch_listener/themes.dart';

class ToggleFilterWidget extends StatefulWidget {
  final RewardAction action;
  final VoidCallback changesCallback;

  const ToggleFilterWidget(
      {super.key, required this.action, required this.changesCallback});

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<ToggleFilterWidget> {
  late final RewardAction _action;

  late final TextEditingController _sourceNameController;
  late final TextEditingController _filterNameController;

  final _sourceNameFocusNode = FocusNode();
  final _filterNameFocusNode = FocusNode();

  @override
  void initState() {
    _action = widget.action;
    _sourceNameController =
        TextEditingController(text: widget.action.sourceName);
    _sourceNameController.addListener(_handleSourceNameEdit);
    _filterNameController =
        TextEditingController(text: widget.action.filterName);
    _filterNameController.addListener(_handleFilterNameEdit);
    super.initState();
  }

  @override
  void dispose() {
    _sourceNameController.removeListener(_handleSourceNameEdit);
    _sourceNameController.dispose();
    _filterNameController.removeListener(_handleFilterNameEdit);
    _filterNameController.dispose();
    _sourceNameFocusNode.dispose();
    _filterNameFocusNode.dispose();
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
              context.localizations.filter_name_title,
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
                    controller: _filterNameController,
                    focusNode: _filterNameFocusNode,
                    textInputAction: TextInputAction.done,
                    style: style,
                    decoration: decoration,
                  );
                },
                hint: context.localizations.filter_name_hint,
                controller: _filterNameController,
                focusNode: _filterNameFocusNode,
                theme: theme)
          ],
        )),
        const Gap(8),
        Expanded(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.localizations.source_name_title,
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
                    controller: _sourceNameController,
                    focusNode: _sourceNameFocusNode,
                    textInputAction: TextInputAction.done,
                    style: style,
                    decoration: decoration,
                  );
                },
                hint: context.localizations.source_name_hint,
                controller: _sourceNameController,
                focusNode: _sourceNameFocusNode,
                theme: theme)
          ],
        )),
        const Gap(8),
        Expanded(
            child: SimpleDropdown<String>(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                theme: theme,
                title: context.localizations.action_title,
                available: [
                  Item(
                      id: 'enable', title: context.localizations.action_enable),
                  Item(
                      id: 'disable',
                      title: context.localizations.action_disable),
                  Item(
                      id: 'toggle', title: context.localizations.action_toggle),
                ],
                globalKey: _actionKey,
                selected: _action.action,
                onSelected: _handleActionSelected))
      ],
    );
  }

  final _actionKey = GlobalKey();

  void _handleSourceNameEdit() {
    _action.sourceName = _sourceNameController.text.trim();
    widget.changesCallback();
  }

  void _handleActionSelected(String action) {
    setState(() {
      _action.action = action;
      widget.changesCallback();
    });
  }

  void _handleFilterNameEdit() {
    _action.filterName = _filterNameController.text.trim();
    widget.changesCallback();
  }
}
