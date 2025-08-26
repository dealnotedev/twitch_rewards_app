import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:twitch_listener/buttons.dart';
import 'package:twitch_listener/custom_switch.dart';
import 'package:twitch_listener/dropdown/dropdown_menu.dart';
import 'package:twitch_listener/dropdown/dropdown_scope.dart';
import 'package:twitch_listener/extensions.dart';
import 'package:twitch_listener/generated/assets.dart';
import 'package:twitch_listener/reward.dart';
import 'package:twitch_listener/ripple_icon.dart';
import 'package:twitch_listener/simple_icon.dart';
import 'package:twitch_listener/simple_indicator.dart';
import 'package:twitch_listener/simple_widgets.dart';
import 'package:twitch_listener/text_field_decoration.dart';
import 'package:twitch_listener/themes.dart';

class RewardConfiguratorWidget extends StatefulWidget {
  final DropdownManager dropdownManager;
  final Reward reward;

  const RewardConfiguratorWidget(
      {super.key, required this.reward, required this.dropdownManager});

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<RewardConfiguratorWidget> {
  late final DropdownManager _dropdownManager;
  late final TextEditingController _nameController;
  late final Reward _reward;

  final _nameFocusNode = FocusNode();

  @override
  void initState() {
    _dropdownManager = widget.dropdownManager;
    _reward = widget.reward;
    _nameController = TextEditingController(text: _reward.name);
    super.initState();
  }

  @override
  void dispose() {
    _nameFocusNode.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => _dropdownManager.clear(),
      behavior: HitTestBehavior.opaque,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 812),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Gap(8),
            _createToolbar(context, theme),
            const Gap(8),
            SimpleDivider(theme: theme),
            Flexible(
                child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Gap(16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Gap(16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.localizations.reward_name_title,
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
                                    decoration: decoration,
                                    style: style,
                                    focusNode: _nameFocusNode,
                                    controller: _nameController,
                                  );
                                },
                                hint: context.localizations.reward_name_hint,
                                controller: _nameController,
                                focusNode: _nameFocusNode,
                                theme: theme)
                          ],
                        ),
                      ),
                      const Gap(16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context
                                    .localizations.reward_status_switch_title,
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: theme.textColorPrimary),
                              ),
                              const Gap(6),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CustomSwitch(
                                    value: !_reward.disabled,
                                    onToggle: _handleStatusChange,
                                    theme: theme,
                                  ),
                                ],
                              )
                            ],
                          ),
                          const Gap(16),
                          CustomButton(
                            key: _addKey,
                            icon: Assets.assetsIcPlusWhite16dp,
                            text: context.localizations.button_add_reaction,
                            style: CustomButtonStyle.secondary,
                            theme: theme,
                            onTap: () {
                              _showAddDropdown(context);
                            },
                          ),
                        ],
                      ),
                      const Gap(16),
                    ],
                  ),
                  const Gap(16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      context.localizations.reaction_chain_title,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: theme.textColorPrimary),
                    ),
                  ),
                  const Gap(16)
                ],
              ),
            ))
          ],
        ),
      ),
    );
  }

  Widget _createToolbar(BuildContext context, ThemeData theme) {
    return Row(
      children: [
        const Gap(16),
        SimpleIcon.simpleSquare(Assets.assetsIcConfigWhite16dp,
            size: 16, color: theme.textColorPrimary),
        const Gap(8),
        Expanded(
            child: Row(
          children: [
            Flexible(
                child: Text(
              context.localizations.reward_configure_title,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.textColorPrimary),
            )),
            const Gap(8),
            SimpleIndicator(
                fontSize: 12,
                text: _reward.disabled
                    ? context.localizations.channel_points_inactive
                    : context.localizations.channel_points_active,
                theme: theme,
                style: _reward.disabled
                    ? IndicatorStyle.outlined
                    : IndicatorStyle.bold),
            const Gap(8),
            SimpleIndicator(
                fontSize: 12,
                text: context.localizations.x_points(9999),
                theme: theme,
                style: IndicatorStyle.neutral),
          ],
        )),
        RippleIcon(
          borderRadius: BorderRadius.circular(8),
          icon: Assets.assetsIcCloseWhite16dp,
          hoverColor: const Color(0xFFD4183D),
          size: 16,
          color: theme.textColorPrimary,
          onTap: () {
            Navigator.of(context).pop();
          },
        ),
        const Gap(8),
      ],
    );
  }

  final _addKey = GlobalKey();

  void _showAddDropdown(BuildContext context) {
    _dropdownManager.show(context, builder: (cntx) {
      return DropdownPopupMenu<String>(
        selected: null,
        items: [
          Item(
              id: RewardAction.typeEnableInput,
              title: context.localizations.reaction_enable_input,
              icon: Assets.assetsIcMicWhite16dp),
          Item(
              id: RewardAction.typeDelay,
              title: context.localizations.reaction_delay,
              icon: Assets.assetsIcClockWhite16dp),
          Item(
              id: RewardAction.typePlayAudio,
              title: context.localizations.reaction_play_audio,
              icon: Assets.assetsIcAudioWhite16dp)
        ],
        onTap: (String type) {
          _dropdownManager.dismiss(_addKey);
        },
      );
    }, key: _addKey);
  }

  void _handleStatusChange(bool value) {
    setState(() {
      _reward.disabled = !value;
    });
  }
}
