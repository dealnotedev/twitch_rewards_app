import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:twitch_listener/custom_switch.dart';
import 'package:twitch_listener/extensions.dart';
import 'package:twitch_listener/reward.dart';
import 'package:twitch_listener/text_field_decoration.dart';
import 'package:twitch_listener/themes.dart';

class FlipSourceWidget extends StatefulWidget {
  final RewardAction action;
  final VoidCallback changesCallback;

  const FlipSourceWidget(
      {super.key, required this.action, required this.changesCallback});

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<FlipSourceWidget> {
  late final RewardAction _action;

  late final TextEditingController _sourceNameController;
  late final TextEditingController _sceneNameController;

  final _sourceNameFocusNode = FocusNode();
  final _sceneNameFocusNode = FocusNode();

  @override
  void initState() {
    _action = widget.action;
    _sourceNameController =
        TextEditingController(text: widget.action.sourceName);
    _sourceNameController.addListener(_handleSourceNameEdit);
    _sceneNameController = TextEditingController(text: widget.action.sceneName);
    _sceneNameController.addListener(_handleSceneNameEdit);
    super.initState();
  }

  @override
  void dispose() {
    _sourceNameController.removeListener(_handleSourceNameEdit);
    _sourceNameController.dispose();
    _sceneNameController.removeListener(_handleSceneNameEdit);
    _sceneNameController.dispose();
    _sourceNameFocusNode.dispose();
    _sceneNameFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
                child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.localizations.scene_name_title,
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
                        controller: _sceneNameController,
                        focusNode: _sceneNameFocusNode,
                        textInputAction: TextInputAction.done,
                        style: style,
                        decoration: decoration,
                      );
                    },
                    hint: context.localizations.scene_name_hint,
                    controller: _sceneNameController,
                    focusNode: _sceneNameFocusNode,
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
          ],
        ),
        const Gap(12),
        Row(
          children: [
            CustomSwitch(
                onToggle: _handleXToggled,
                value: _action.horizontal,
                theme: theme),
            const Gap(8),
            Text(
              context.localizations.reaction_flip_source_x,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: theme.textColorPrimary),
            ),
            const Gap(12),
            CustomSwitch(
                onToggle: _handleYToggled,
                value: _action.vertical,
                theme: theme),
            const Gap(8),
            Text(
              context.localizations.reaction_flip_source_y,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: theme.textColorPrimary),
            )
          ],
        )
      ],
    );
  }

  void _handleSourceNameEdit() {
    _action.sourceName = _sourceNameController.text.trim();
    widget.changesCallback();
  }

  void _handleSceneNameEdit() {
    _action.sceneName = _sceneNameController.text.trim();
    widget.changesCallback();
  }

  void _handleXToggled(bool checked) {
    setState(() {
      _action.horizontal = checked;
      widget.changesCallback();
    });
  }

  void _handleYToggled(bool checked) {
    setState(() {
      _action.vertical = checked;
      widget.changesCallback();
    });
  }
}
