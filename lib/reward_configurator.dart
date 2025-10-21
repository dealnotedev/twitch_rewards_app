import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:lottie/lottie.dart';
import 'package:twitch_listener/actions/crash_process.dart';
import 'package:twitch_listener/actions/delay.dart';
import 'package:twitch_listener/actions/enable_input.dart';
import 'package:twitch_listener/actions/flip_source.dart';
import 'package:twitch_listener/actions/play_audio.dart';
import 'package:twitch_listener/actions/play_audios.dart';
import 'package:twitch_listener/actions/send_input.dart';
import 'package:twitch_listener/actions/set_scene.dart';
import 'package:twitch_listener/actions/toggle_filter.dart';
import 'package:twitch_listener/actions/toggle_source.dart';
import 'package:twitch_listener/app_router.dart';
import 'package:twitch_listener/audioplayer.dart';
import 'package:twitch_listener/autosaver.dart';
import 'package:twitch_listener/buttons.dart';
import 'package:twitch_listener/custom_switch.dart';
import 'package:twitch_listener/dropdown/dropdown_menu.dart';
import 'package:twitch_listener/dropdown/dropdown_scope.dart';
import 'package:twitch_listener/empty_widget.dart';
import 'package:twitch_listener/extensions.dart';
import 'package:twitch_listener/generated/assets.dart';
import 'package:twitch_listener/reward.dart';
import 'package:twitch_listener/reward_executor.dart';
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
  final RewardExecutor executor;
  final Reward reward;
  final Autosaver autosaver;

  const RewardConfiguratorWidget(
      {super.key,
      required this.reward,
      required this.audioplayer,
      required this.twitchShared,
      required this.executor,
      required this.autosaver});

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
    final actions = _reward.handlers;

    return Container(
      color: theme.surfacePrimary,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Gap(8),
          _createToolbar(context, theme),
          const Gap(8),
          SimpleDivider(theme: theme),
          Expanded(
              child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Gap(16),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                      color: theme.surfaceSecondary,
                      border: Border.all(
                          color: theme.dividerColor,
                          width: 0.5,
                          strokeAlign: BorderSide.strokeAlignOutside),
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.localizations.reward_configigure_basic_settings,
                        style: TextStyle(
                            fontSize: 14, color: theme.textColorPrimary),
                      ),
                      const Gap(8),
                      Row(
                        children: [
                          Expanded(
                              flex: 2,
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
                                      hint: context
                                          .localizations.reward_name_hint,
                                      controller: _nameController,
                                      focusNode: _nameFocusNode,
                                      theme: theme),
                                ],
                              )),
                          const Gap(16),
                          Expanded(
                              flex: 1,
                              child: Lottie.asset(Assets.assetsRex,
                                  width: 50,
                                  height: 60,
                                  frameRate: FrameRate.max))
                        ],
                      ),
                      const Gap(8),
                      Row(
                        children: [
                          CustomSwitch(
                            value: !_reward.disabled,
                            onToggle: _handleStatusChange,
                            theme: theme,
                          ),
                          const Gap(8),
                          Expanded(
                              child: Text(
                            _reward.disabled
                                ? context.localizations.reward_status_inactive
                                : context.localizations.reward_status_active,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: theme.textColorPrimary),
                          ))
                        ],
                      )
                    ],
                  ),
                ),
                const Gap(16),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                      color: theme.surfaceSecondary,
                      border: Border.all(
                          color: theme.dividerColor,
                          width: 0.5,
                          strokeAlign: BorderSide.strokeAlignOutside),
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.only(
                      top: 16, left: 16, right: 16, bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                              child: Text(
                            context.localizations.reaction_chain_title,
                            style: TextStyle(
                                fontSize: 14, color: theme.textColorPrimary),
                          )),
                          CustomButton(
                            prefixIcon: Assets.assetsIcPlayWhite16dp,
                            text: '',
                            style: CustomButtonStyle.secondary,
                            theme: theme,
                            onTap: () {
                              widget.executor.execute(_reward);
                            },
                          ),
                          const Gap(8),
                          CustomButton(
                            key: _addKey,
                            prefixIcon: Assets.assetsIcPlusWhite16dp,
                            suffixIcon: Assets.assetsIcArrowDownWhite16dp,
                            text: context.localizations.button_add_reaction,
                            style: CustomButtonStyle.secondary,
                            theme: theme,
                            onTap: () {
                              _showAddDropdown(context);
                            },
                          ),
                        ],
                      ),
                      if (actions.isEmpty) ...[
                        const Gap(8),
                        EmptyWidget(
                            text:
                                context.localizations.reaction_chain_empty_text,
                            theme: theme),
                      ] else ...[
                        const Gap(4),
                        ReorderableList(
                            shrinkWrap: true,
                            itemBuilder: (context, index) {
                              final action = actions[index];
                              return _ActionWidget(
                                  index: index,
                                  audioplayer: widget.audioplayer,
                                  changesCallback: _notifyActionsChanges,
                                  onDelete: () => _handleActionDelete(action),
                                  key: ValueKey(action.id),
                                  action: action,
                                  theme: theme);
                            },
                            itemCount: actions.length,
                            onReorder: (oldIndex, newIndex) {
                              setState(() {
                                if (oldIndex < newIndex) {
                                  newIndex -= 1;
                                }
                                final item = actions.removeAt(oldIndex);
                                actions.insert(newIndex, item);

                                _notifyActionsChanges();
                              });
                            })
                      ]
                    ],
                  ),
                ),
              ],
            ),
          ))
        ],
      ),
    );
  }

  void _notifyActionsChanges() {
    widget.autosaver.notifyChanges();
  }

  Widget _createBackButton(BuildContext context, ThemeData theme) {
    final radius = BorderRadius.circular(8);
    return Material(
        type: MaterialType.transparency,
        borderRadius: radius,
        child: InkWell(
          onTap: () {
            ApplicationRouter.pop(context);
          },
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                SimpleIcon.simpleSquare(Assets.assetsIcBackWhite16dp,
                    size: 16, color: theme.textColorPrimary),
                const Gap(4),
                Text(
                  context.localizations.button_back,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.textColorPrimary),
                )
              ],
            ),
          ),
        ));
  }

  Widget _createToolbar(BuildContext context, ThemeData theme) {
    return Row(
      children: [
        const Gap(8),
        _createBackButton(context, theme),
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
        ))
      ],
    );
  }

  final _addKey = GlobalKey();

  void _showAddDropdown(BuildContext context) {
    final manager = DropdownScope.of(context);

    manager.show(context, builder: (cntx) {
      return DropdownPopupMenu<String>(
        selected: null,
        items: RewardAction.availableTypes
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
      _notifyActionsChanges();
    });
  }

  void _handleNameEdit() {
    _reward.name = _nameController.text;
    _notifyActionsChanges();
  }

  void _handleAddActionClick(String type) {
    final action = RewardAction.create(type);

    setState(() {
      _reward.handlers.add(action);
      _notifyActionsChanges();
    });
  }

  void _handleActionDelete(RewardAction action) {
    setState(() {
      _reward.handlers.remove(action);
      _notifyActionsChanges();
    });
  }
}

class _ActionWidget extends StatelessWidget {
  final int index;
  final Audioplayer audioplayer;
  final ThemeData theme;
  final RewardAction action;
  final VoidCallback onDelete;
  final VoidCallback changesCallback;

  const _ActionWidget(
      {super.key,
      required this.action,
      required this.theme,
      required this.onDelete,
      required this.audioplayer,
      required this.index,
      required this.changesCallback});

  @override
  Widget build(BuildContext context) {
    final attrs = RewardActionAtts.forType(context, action.type);

    final borderDefault = BorderSide(
      color: theme.dividerColor,
      width: 0.5,
    );
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      width: double.infinity,
      decoration: BoxDecoration(
          color: theme.surfaceSecondary,
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(
              color: theme.dividerColor,
              strokeAlign: BorderSide.strokeAlignOutside,
              width: 4,
            ),
            top: borderDefault,
            right: borderDefault,
            bottom: borderDefault,
          )),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Gap(8),
          Row(
            children: [
              const Gap(8),
              ReorderableDragStartListener(
                  index: index,
                  child: RippleIcon(
                      icon: Assets.assetsIcReorderWhite16dp,
                      size: 16,
                      color: theme.textColorSecondary)),
              const Gap(4),
              SimpleIcon.simpleSquare(attrs.icon,
                  size: 16, color: theme.textColorPrimary),
              const Gap(12),
              Text(
                _getActionTitle(context, attrs: attrs),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: theme.textColorPrimary),
              ),
              Expanded(child: _createAdditionalHeaderWidget(context, theme)),
              RippleIcon(
                  borderRadius: BorderRadius.circular(8),
                  icon: Assets.assetsIcDeleteWhite16dp,
                  onTap: onDelete,
                  size: 16,
                  color: theme.textColorPrimary),
              const Gap(8),
            ],
          ),
          const Gap(8),
          ..._createCustomWidgets(context, theme)
        ],
      ),
    );
  }

  static String _getActionTitle(BuildContext context,
      {required RewardActionAtts attrs}) {
    switch (attrs.type) {
      case RewardAction.typeDelay:
        return context.localizations.reaction_delay_title;
      default:
        return attrs.title;
    }
  }

  List<Widget> _createCustomWidgets(BuildContext context, ThemeData theme) {
    if ([RewardAction.typeDelay, RewardAction.typeSendInput]
        .contains(action.type)) {
      return [];
    }
    return [
      SimpleDivider(theme: theme),
      Padding(
        padding: const EdgeInsets.all(16),
        child: _createInternal(context, theme),
      ),
    ];
  }

  Widget _createAdditionalHeaderWidget(BuildContext context, ThemeData theme) {
    switch (action.type) {
      case RewardAction.typeDelay:
        return Padding(
          padding: const EdgeInsetsDirectional.only(start: 12, end: 8),
          child: DelayWidget(action: action, changesCallback: changesCallback),
        );

      case RewardAction.typeSendInput:
        return Padding(
          padding: const EdgeInsetsDirectional.only(start: 12, end: 8),
          child:
              SendInputWidget(action: action, changesCallback: changesCallback),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _createInternal(BuildContext context, ThemeData theme) {
    switch (action.type) {
      case RewardAction.typePlayAudios:
        return PlayAudiosWidget(
            action: action,
            audioplayer: audioplayer,
            changesCallback: changesCallback);

      case RewardAction.typePlayAudio:
        return PlayAudioWidget(
            action: action,
            audioplayer: audioplayer,
            changesCallback: changesCallback);

      case RewardAction.typeCrashProcess:
        return CrashProcessWidget(
            action: action, changesCallback: changesCallback);

      case RewardAction.typeToggleSource:
        return ToggleSourceWidget(
            action: action, changesCallback: changesCallback);

      case RewardAction.typeFlipSource:
        return FlipSourceWidget(
            action: action, changesCallback: changesCallback);

      case RewardAction.typeEnableInput:
        return EnableInputWidget(
            action: action, changesCallback: changesCallback);

      case RewardAction.typeToggleFilter:
        return ToggleFilterWidget(
            action: action, changesCallback: changesCallback);

      case RewardAction.typeSetScene:
        return SetSceneWidget(action: action, changesCallback: changesCallback);
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
