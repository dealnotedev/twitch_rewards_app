import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:twitch_listener/buttons.dart';
import 'package:twitch_listener/dropdown/dropdown_menu.dart';
import 'package:twitch_listener/dropdown/dropdown_scope.dart';
import 'package:twitch_listener/extensions.dart';
import 'package:twitch_listener/generated/assets.dart';
import 'package:twitch_listener/reward.dart';
import 'package:twitch_listener/ripple_icon.dart';
import 'package:twitch_listener/settings.dart';
import 'package:twitch_listener/simple_icon.dart';
import 'package:twitch_listener/simple_indicator.dart';
import 'package:twitch_listener/text_field_decoration.dart';
import 'package:twitch_listener/themes.dart';

class RewardsStateWidget extends StatefulWidget {
  final Settings settings;

  const RewardsStateWidget({super.key, required this.settings});

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<RewardsStateWidget> {
  final _controler = TextEditingController();
  final _focusNode = FocusNode();

  late final Settings _settings;

  @override
  void initState() {
    _settings = widget.settings;
    super.initState();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controler.dispose();
    super.dispose();
  }

  final _addKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final all = _settings.rewards.rewards;

    final total = all.length;
    final active = all.where((r) => !r.disabled).length;
    final actions = all.map((r) => r.handlers.length).sum;

    const indicatorPadding =
        EdgeInsets.only(left: 6, right: 8, top: 3, bottom: 3);
    const indicatorStyle =
        TextStyle(fontSize: 10, fontWeight: FontWeight.w600, height: 1);

    return Container(
        width: double.infinity,
        decoration: BoxDecoration(
            color: theme.surfaceSecondary,
            border: Border.all(
                color: theme.dividerColor,
                width: 0.5,
                strokeAlign: BorderSide.strokeAlignOutside),
            borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.all(16),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SimpleIcon.simpleSquare(Assets.assetsIcThunderWhite16dp,
                      size: 16, color: theme.textColorPrimary),
                  const Gap(8),
                  Expanded(
                      child: Text(
                    context.localizations.channel_points_config_title,
                    style:
                        TextStyle(fontSize: 14, color: theme.textColorPrimary),
                  ))
                ],
              ),
              const Gap(4),
              Row(
                children: [
                  SimpleIndicator(
                      text: context.localizations.x_total(total),
                      theme: theme,
                      style: IndicatorStyle.neutral),
                  const Gap(4),
                  SimpleIndicator(
                      text: context.localizations.x_active(active),
                      theme: theme,
                      style: IndicatorStyle.bold),
                  const Gap(4),
                  SimpleIndicator(
                      text: context.localizations.x_actions(actions),
                      theme: theme,
                      style: IndicatorStyle.outlined),
                  const Expanded(child: SizedBox.shrink()),
                  CustomButton(
                    key: _addKey,
                    icon: Assets.assetsIcPlusWhite16dp,
                    text: context.localizations.button_add_channel_points,
                    style: CustomButtonStyle.primary,
                    theme: theme,
                    onTap: () {
                      _showAddDropdown(context);
                    },
                  )
                ],
              ),
              const Gap(16),
              TextFieldDecoration(
                  clearable: true,
                  prefix: SimpleIcon.simpleSquare(
                      Assets.assetsIcSearchWhite16dp,
                      size: 16,
                      color: theme.textColorSecondary),
                  builder: (cntx, decoration, style) {
                    return TextField(
                      controller: _controler,
                      focusNode: _focusNode,
                      textInputAction: TextInputAction.search,
                      style: style,
                      decoration: decoration,
                    );
                  },
                  hint: context.localizations.reward_search_hint,
                  controller: _controler,
                  focusNode: _focusNode,
                  theme: theme),
              const Gap(12),
              ...all.map((r) => _RewardWidget(reward: r, theme: theme))
            ]));
  }

  void _showAddDropdown(BuildContext context) {
    final manager = DropdownScope.of(context);
    manager.show(context, builder: (cntx) {
      return DropdownPopupMenu<bool>(
        selected: null,
        items: [
          Item(id: true, title: context.localizations.yes),
          Item(id: false, title: context.localizations.no)
        ],
        onTap: (bool id) {
          manager.dismiss(_addKey);
        },
      );
    }, key: _addKey);
  }
}

class _RewardWidget extends StatefulWidget {
  final ThemeData theme;
  final Reward reward;

  const _RewardWidget({super.key, required this.reward, required this.theme});

  @override
  State<StatefulWidget> createState() => _RewardState();
}

class _RewardState extends State<_RewardWidget> {
  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final reward = widget.reward;

    final reactions = reward.handlers.length;
    final reactionsEnabled = reward.handlers.map((h) => !h.disabled).length;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      width: double.infinity,
      decoration: BoxDecoration(
          color: theme.surfaceSecondary,
          border: Border.all(
              color: theme.dividerColor,
              width: 0.5,
              strokeAlign: BorderSide.strokeAlignOutside),
          borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    reward.name,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.textColorPrimary),
                  ),
                  const Gap(8),
                  SimpleIndicator(
                      text: context.localizations.x_points(106),
                      theme: theme,
                      style: IndicatorStyle.neutral),
                  const Gap(4),
                  SimpleIndicator(
                      text: reward.disabled
                          ? context.localizations.channel_points_inactive
                          : context.localizations.channel_points_active,
                      theme: theme,
                      style: reward.disabled
                          ? IndicatorStyle.outlined
                          : IndicatorStyle.bold)
                ],
              ),
              const Gap(4),
              Text(
                context.localizations
                    .channel_points_reactions_info(reactions, reactionsEnabled),
                style: TextStyle(fontSize: 10, color: theme.textColorSecondary),
              )
            ],
          )),
          const Gap(12),
          CustomButton(
            icon: Assets.assetsIcSettingsWhite12dp,
            text: context.localizations.button_configure,
            style: CustomButtonStyle.secondary,
            theme: theme,
            onTap: () {},
          ),
          const Gap(8),
          CustomButton(
            icon: Assets.assetsIcPlayWhite12dp,
            text: '',
            style: CustomButtonStyle.secondary,
            theme: theme,
            onTap: () {},
          ),
          const Gap(8),
          RippleIcon(
            size: 12,
            icon: Assets.assetsIcMoreWhite12dp,
            color: theme.textColorPrimary,
            padding: 4,
            onTap: () {},
          )
        ],
      ),
    );
  }
}
