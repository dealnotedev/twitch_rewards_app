import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:twitch_listener/buttons.dart';
import 'package:twitch_listener/dropdown/dropdown_menu.dart';
import 'package:twitch_listener/dropdown/dropdown_scope.dart';
import 'package:twitch_listener/extensions.dart';
import 'package:twitch_listener/generated/assets.dart';
import 'package:twitch_listener/settings.dart';
import 'package:twitch_listener/simple_icon.dart';
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
    final total = _settings.rewards.rewards.length;
    final active = _settings.rewards.rewards.where((r) => !r.disabled).length;
    final actions = _settings.rewards.rewards.map((r) => r.handlers.length).sum;

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
                  SimpleIcon.simpleSquare(Assets.assetsIcSettingsWhite16dp,
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
                  Container(
                    padding: indicatorPadding,
                    decoration: BoxDecoration(
                        color: theme.buttonColorAlternative,
                        borderRadius: BorderRadius.circular(6)),
                    child: Text(
                      context.localizations.x_total(total),
                      style: indicatorStyle.copyWith(
                          color: theme.textColorPrimary),
                    ),
                  ),
                  const Gap(4),
                  Container(
                    padding: indicatorPadding,
                    decoration: BoxDecoration(
                        color: theme.buttonColorPrimary,
                        borderRadius: BorderRadius.circular(6)),
                    child: Text(
                      context.localizations.x_active(active),
                      style: indicatorStyle.copyWith(
                          color: theme.textColorPrimaryInverted),
                    ),
                  ),
                  const Gap(4),
                  Container(
                    padding: indicatorPadding,
                    decoration: BoxDecoration(
                        color: theme.buttonColorSecondary,
                        border: Border.all(
                            color: theme.dividerColor,
                            width: 0.5,
                            strokeAlign: BorderSide.strokeAlignOutside),
                        borderRadius: BorderRadius.circular(6)),
                    child: Text(
                      context.localizations.x_actions(actions),
                      style: indicatorStyle.copyWith(
                          color: theme.textColorPrimary),
                    ),
                  ),
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
                  theme: theme)
            ]));
  }

  void _showAddDropdown(BuildContext context) {
    final manager = DropdownScope.of(context);
    manager.show(context, builder: (cntx) {
      return DropdownPopupMenu<bool>(
        selected: true,
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
