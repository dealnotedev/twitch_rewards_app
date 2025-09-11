import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:twitch_listener/buttons.dart';
import 'package:twitch_listener/extensions.dart';
import 'package:twitch_listener/generated/assets.dart';
import 'package:twitch_listener/reward.dart';
import 'package:twitch_listener/ripple_icon.dart';
import 'package:twitch_listener/text_field_decoration.dart';
import 'package:twitch_listener/themes.dart';

class SetSceneWidget extends StatefulWidget {
  final RewardAction action;

  const SetSceneWidget({super.key, required this.action});

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<SetSceneWidget> {
  late final RewardAction _action;

  final TextEditingController _sceneNameController = TextEditingController();
  final _sceneNameFocusNode = FocusNode();

  @override
  void initState() {
    _action = widget.action;
    _sceneNameController.addListener(_handleSceneNameEdit);
    super.initState();
  }

  @override
  void dispose() {
    _sceneNameController.removeListener(_handleSceneNameEdit);
    _sceneNameController.dispose();
    _sceneNameFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
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
                        onSubmitted: _handleSubmit,
                        style: style,
                        decoration: decoration,
                      );
                    },
                    hint: context.localizations.reaction_set_scene_name_hint,
                    controller: _sceneNameController,
                    focusNode: _sceneNameFocusNode,
                    theme: theme)
              ],
            )),
            const Gap(8),
            CustomButton(
              prefixIcon: Assets.assetsIcPlusWhite16dp,
              text: '',
              style: CustomButtonStyle.secondary,
              theme: theme,
              onTap: _canAdd
                  ? () {
                      _handleSubmit(_sceneNameController.text);
                    }
                  : null,
            ),
          ],
        ),
        if (_action.targets.isNotEmpty) ...[
          const Gap(12),
          Wrap(
            spacing: 6,
            children: _action.targets
                .map((t) => _createTargetWidget(context, theme, target: t))
                .toList(),
          )
        ]
      ],
    );
  }

  bool _canAdd = false;

  Widget _createTargetWidget(BuildContext context, ThemeData theme,
      {required String target}) {
    return Container(
      decoration: BoxDecoration(
        color: theme.inputBackground,
        border: Border.all(
            color: theme.dividerColor,
            width: 0.5,
            strokeAlign: BorderSide.strokeAlignOutside),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Gap(12),
          Text(
            target,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.textColorPrimary),
          ),
          const Gap(4),
          RippleIcon(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              _handleTargetDeleteClick(target);
            },
            padding: 4,
            size: 16,
            icon: Assets.assetsIcCloseWhite16dp,
            color: theme.textColorPrimary,
          ),
        ],
      ),
    );
  }

  void _handleSceneNameEdit() {
    final canAdd = _sceneNameController.text.trim().isNotEmpty;
    if (_canAdd != canAdd) {
      setState(() {
        _canAdd = canAdd;
      });
    }
  }

  void _handleSubmit(String sceneName) {
    if (sceneName.isEmpty) return;

    if (_action.targets.contains(sceneName)) {
      return;
    }

    setState(() {
      _sceneNameController.text = '';
      _action.targets.add(sceneName);
    });
  }

  void _handleTargetDeleteClick(String target) {
    setState(() {
      _action.targets.remove(target);
    });
  }
}
