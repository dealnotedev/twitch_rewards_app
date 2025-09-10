import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:lottie/lottie.dart';
import 'package:twitch_listener/actions/play_audios.dart';
import 'package:twitch_listener/audioplayer.dart';
import 'package:twitch_listener/buttons.dart';
import 'package:twitch_listener/custom_switch.dart';
import 'package:twitch_listener/dropdown/dropdown_menu.dart';
import 'package:twitch_listener/dropdown/dropdown_scope.dart';
import 'package:twitch_listener/empty_widget.dart';
import 'package:twitch_listener/extensions.dart';
import 'package:twitch_listener/generated/assets.dart';
import 'package:twitch_listener/reward.dart';
import 'package:twitch_listener/reward_ext.dart';
import 'package:twitch_listener/ripple_icon.dart';
import 'package:twitch_listener/simple_icon.dart';
import 'package:twitch_listener/simple_indicator.dart';
import 'package:twitch_listener/simple_widgets.dart';
import 'package:twitch_listener/text_field_decoration.dart';
import 'package:twitch_listener/themes.dart';
import 'package:twitch_listener/twitch_shared.dart';

class RewardConfiguratorWidget extends StatefulWidget {
  final TwitchShared twitchShared;
  final Audioplayer audioplayer;
  final Reward reward;

  const RewardConfiguratorWidget(
      {super.key,
      required this.reward,
      required this.audioplayer,
      required this.twitchShared});

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<RewardConfiguratorWidget> {
  late final TextEditingController _nameController;
  late final Reward _reward;

  final _nameFocusNode = FocusNode();

  @override
  void initState() {
    _reward = widget.reward;
    _nameController = TextEditingController(text: _reward.name);
    _nameController.addListener(_handleNameEdit);
    super.initState();
  }

  @override
  void dispose() {
    _nameFocusNode.dispose();
    _nameController.dispose();
    _nameController.removeListener(_handleNameEdit);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => DropdownScope.of(context).clear(),
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
                      Expanded(
                          child: Container(
                        child: Lottie.asset(Assets.assetsRex,
                            height: 60, width: 50, frameRate: FrameRate.max),
                      )),
                    ],
                  ),
                  const Gap(16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Gap(16),
                      Expanded(
                          child: Text(
                        context.localizations.reaction_chain_title,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: theme.textColorPrimary),
                      )),
                      CustomButton(
                        key: _addKey,
                        prefixIcon: Assets.assetsIcPlusWhite16dp,
                        suffixIcon: Assets.assetsIcArrowDownWhite16dp,
                        text: context.localizations.button_add_reaction,
                        style: CustomButtonStyle.primary,
                        theme: theme,
                        onTap: () {
                          _showAddDropdown(context);
                        },
                      ),
                      const Gap(16)
                    ],
                  ),
                  if (_reward.handlers.isEmpty) ...[
                    const Gap(8),
                    EmptyWidget(
                        text: context.localizations.reaction_chain_empty_text,
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        theme: theme),
                    const Gap(16),
                  ] else ...[
                    const Gap(4),
                    ..._reward.handlers.map((a) => _ActionWidget(
                        audioplayer: widget.audioplayer,
                        onDelete: () => _handleActionDelete(a),
                        key: ValueKey(a.id),
                        action: a,
                        theme: theme)),
                    const Gap(12),
                  ]
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
            StreamBuilder(
                stream: _nameController.stream(),
                initialData: _nameController.text,
                builder: (cntx, name) {
                  final found =
                      widget.twitchShared.redemptions.current[name.requireData];
                  return Row(
                    children: [
                      if (found != null) ...[
                        const Gap(8),
                        SimpleIndicator(
                            fontSize: 12,
                            text: context.localizations.x_points(found.cost),
                            theme: theme,
                            style: IndicatorStyle.neutral),
                      ]
                    ],
                  );
                }),
          ],
        )),
        CustomSwitch(
          value: !_reward.disabled,
          onToggle: _handleStatusChange,
          theme: theme,
        ),
        const Gap(8),
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

  Widget _createStatusWidget(BuildContext context, ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.localizations.reward_status_switch_title,
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
    );
  }

  final _addKey = GlobalKey();

  void _showAddDropdown(BuildContext context) {
    final manager = DropdownScope.of(context);

    manager.show(context, builder: (cntx) {
      return DropdownPopupMenu<String>(
        selected: null,
        items: RewardAction.allTypes
            .map((t) => RewardActionAtts.forType(context, t))
            .map((a) => Item(id: a.type, title: a.title, icon: a.icon))
            .toList(),
        onTap: (String type) {
          manager.dismiss(_addKey);
          _handleAddActionClick(type);
        },
      );
    }, key: _addKey);
  }

  void _handleStatusChange(bool value) {
    setState(() {
      _reward.disabled = !value;
    });
  }

  void _handleNameEdit() {
    _reward.name = _nameController.text;
  }

  void _handleAddActionClick(String type) {
    final action = RewardAction(type: type);
    setState(() {
      _reward.handlers.add(action);
    });
  }

  void _handleActionDelete(RewardAction action) {
    setState(() {
      _reward.handlers.remove(action);
    });
  }
}

class _ActionWidget extends StatefulWidget {
  final Audioplayer audioplayer;
  final ThemeData theme;
  final RewardAction action;
  final VoidCallback? onDelete;

  const _ActionWidget(
      {super.key,
      required this.action,
      required this.theme,
      this.onDelete,
      required this.audioplayer});

  @override
  State<StatefulWidget> createState() => _ActionState();
}

class _ActionState extends State<_ActionWidget> {
  late final RewardAction _action;

  @override
  void initState() {
    _action = widget.action;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final attrs = RewardActionAtts.forType(context, _action.type);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      width: double.infinity,
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor, width: 0.5)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Gap(8),
          Row(
            children: [
              const Gap(8),
              RippleIcon(
                  icon: Assets.assetsIcReorderWhite16dp,
                  size: 16,
                  color: theme.textColorSecondary),
              const Gap(4),
              SimpleIcon.simpleSquare(attrs.icon,
                  size: 16, color: theme.textColorPrimary),
              const Gap(12),
              Expanded(
                  child: Text(
                attrs.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, color: theme.textColorPrimary),
              )),
              const Gap(12),
              CustomSwitch(
                  onToggle: _handleToggle,
                  value: !_action.disabled,
                  theme: theme),
              const Gap(8),
              RippleIcon(
                  borderRadius: BorderRadius.circular(8),
                  icon: Assets.assetsIcDeleteWhite16dp,
                  onTap: widget.onDelete,
                  size: 16,
                  color: theme.textColorPrimary),
              const Gap(8),
            ],
          ),
          const Gap(8),
          SimpleDivider(theme: theme),
          Padding(
            padding: const EdgeInsets.all(16),
            child: _createInternal(context, theme),
          ),
        ],
      ),
    );
  }

  void _handleToggle(bool checked) {
    setState(() {
      _action.disabled = !checked;
    });
  }

  Widget _createInternal(BuildContext context, ThemeData theme) {
    switch (_action.type) {
      case RewardAction.typePlayAudios:
        return PlayAudiosWidget(
            action: _action, audioplayer: widget.audioplayer);
    }

    return Container(
      padding: const EdgeInsets.all(8),
      width: double.infinity,
      child: Text(
        'Not yet implemented',
        textAlign: TextAlign.center,
        style: TextStyle(color: theme.textColorSecondary, fontSize: 12),
      ),
    );
  }
}
