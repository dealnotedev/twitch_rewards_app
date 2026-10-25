import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:twitch_listener/app/app_router.dart';
import 'package:twitch_listener/ui/buttons.dart';
import 'package:twitch_listener/core/extensions.dart';
import 'package:twitch_listener/generated/assets.dart';
import 'package:twitch_listener/ui/outline_icons.dart';
import 'package:twitch_listener/rewards/reward.dart';
import 'package:twitch_listener/ui/ripple_icon.dart';
import 'package:twitch_listener/ui/simple_icon.dart';
import 'package:twitch_listener/ui/simple_indicator.dart';
import 'package:twitch_listener/ui/text_field_decoration.dart';
import 'package:twitch_listener/ui/themes.dart';
import 'package:twitch_listener/twitch/dto.dart';
import 'package:twitch_listener/twitch/reward_page.dart';
import 'package:twitch_listener/twitch/rewards_controller.dart';

enum _RewardFilter { all, withoutReactions }

class TwitchRewardCatalog extends StatefulWidget {
  final TwitchRewardsController controller;
  final Reward target;
  const TwitchRewardCatalog({
    super.key,
    required this.controller,
    required this.target,
  });

  @override
  State<TwitchRewardCatalog> createState() => _TwitchRewardCatalogState();
}

class _TwitchRewardCatalogState extends State<TwitchRewardCatalog> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  final _selectedRow = GlobalKey();
  _RewardFilter _filter = _RewardFilter.all;
  String? _selectedId;
  String? _account;
  TwitchRewardsError? _selectionError;
  TwitchRewardsController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _search.addListener(_searchChanged);
    _account = _controller.accountKey;
    if (widget.target.twitchBroadcasterId ==
        _controller.settings.twitchAuth?.broadcasterId) {
      _selectedId = widget.target.twitchRewardId;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.refresh();
    });
  }

  @override
  void dispose() {
    _search.removeListener(_searchChanged);
    _searchFocus.dispose();
    _search.dispose();
    super.dispose();
  }

  void _searchChanged() => setState(() {});

  bool _hasReactions(RedemptionDto remote) =>
      _controller.settings.rewards.rewards.any(
        (local) =>
            local.handlers.isNotEmpty &&
            (local.isLinked
                ? local.twitchRewardId == remote.id &&
                      local.twitchBroadcasterId ==
                          _controller.shared.broadcasterId
                : local.name == remote.title),
      );

  Future<void> _openEditor([RedemptionDto? reward]) async {
    final saved = await ApplicationRouter.openTwitchRewardEditor(
      context,
      reward: reward,
    );
    if (!mounted || saved == null) return;
    setState(() {
      _selectedId = saved.id;
      _selectionError = null;
      _search.clear();
      _filter = _RewardFilter.all;
    });
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final rowContext = _selectedRow.currentContext;
    if (rowContext != null && rowContext.mounted) {
      await Scrollable.ensureVisible(rowContext, alignment: .5);
    }
  }

  void _link(String id) {
    try {
      final selection = _controller.select(id);
      Navigator.pop(context, selection);
    } on TwitchRewardsException catch (error) {
      setState(() => _selectionError = error.kind);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) {
      final theme = Theme.of(context);
      final l10n = context.localizations;
      if (_account != _controller.accountKey) {
        _account = _controller.accountKey;
        _selectedId = null;
      }
      final rewards =
          _controller.rewards
              .where(
                (reward) =>
                    reward.title.toLowerCase().contains(
                      _search.text.toLowerCase(),
                    ) &&
                    (_filter != _RewardFilter.withoutReactions ||
                        !_hasReactions(reward)),
              )
              .toList()
            ..sort((a, b) {
              final byCost = a.cost.compareTo(b.cost);
              return byCost != 0
                  ? byCost
                  : a.title.toLowerCase().compareTo(b.title.toLowerCase());
            });
      final selected = _controller.rewards
          .where((reward) => reward.id == _selectedId)
          .firstOrNull;
      final error = _selectionError ?? _controller.error;
      return TwitchRewardPage(
        title: l10n.twitch_rewards_title,
        onBack: () => ApplicationRouter.pop(context),
        actions: [
          CustomButton(
            text: l10n.twitch_rewards_refresh,
            prefixIcon: OutlineIcons.refresh,
            style: CustomButtonStyle.secondary,
            theme: theme,
            loading: _controller.loading,
            onTap: _controller.loading || _controller.authorizing
                ? null
                : _controller.refresh,
          ),
          CustomButton(
            text: l10n.twitch_rewards_save,
            prefixIcon: Assets.assetsIcSaveWhite16dp,
            style: CustomButtonStyle.primary,
            theme: theme,
            onTap:
                selected == null ||
                    _controller.loading ||
                    !_controller.connected
                ? null
                : () => _link(selected.id),
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _card(theme, [
              TextFieldDecoration(
                theme: theme,
                controller: _search,
                focusNode: _searchFocus,
                hint: l10n.twitch_rewards_search,
                prefix: SimpleIcon.simpleSquare(
                  Assets.assetsIcSearchWhite16dp,
                  size: 16,
                  color: theme.textColorSecondary,
                ),
                builder: (context, decoration, style) => TextField(
                  controller: _search,
                  focusNode: _searchFocus,
                  textInputAction: TextInputAction.search,
                  style: style,
                  decoration: decoration,
                ),
              ),
              const Gap(12),
              Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: 8,
                        children: [
                          for (final entry in {
                            _RewardFilter.all: l10n.twitch_rewards_all,
                            _RewardFilter.withoutReactions:
                                l10n.twitch_rewards_without_reactions,
                          }.entries)
                            CustomButton(
                              text: entry.value,
                              theme: theme,
                              style: _filter == entry.key
                                  ? CustomButtonStyle.primary
                                  : CustomButtonStyle.secondary,
                              onTap: () => setState(() => _filter = entry.key),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const Gap(16),
                  CustomButton(
                    text: l10n.twitch_rewards_create,
                    prefixIcon: Assets.assetsIcPlusWhite16dp,
                    style: CustomButtonStyle.primary,
                    theme: theme,
                    onTap:
                        _controller.canManage &&
                            !_controller.loading &&
                            !_controller.authorizing
                        ? () => _openEditor()
                        : null,
                  ),
                ],
              ),
              if (error != null) ...[
                const Gap(12),
                Text(
                  twitchRewardsErrorMessage(context, error),
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ],
              if (!_controller.connected ||
                  (!_controller.loading && !_controller.canManage)) ...[
                const Gap(12),
                Text(
                  _controller.permissionError
                      ? l10n.twitch_rewards_permissions_failed
                      : _controller.connected
                      ? l10n.twitch_rewards_permission
                      : l10n.twitch_rewards_error_connection,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.textColorSecondary,
                  ),
                ),
                const Gap(8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: CustomButton(
                    text: _controller.connected
                        ? l10n.twitch_rewards_reconnect
                        : l10n.twitch_rewards_connect,
                    style: CustomButtonStyle.secondary,
                    theme: theme,
                    loading: _controller.authorizing,
                    onTap: _controller.authorizing ? null : _controller.connect,
                  ),
                ),
              ],
            ]),
            if (rewards.isNotEmpty) ...[
              const Gap(16),
              _card(theme, [
                if (!_controller.manageabilityKnown)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 8,
                    children: [
                      for (final reward in rewards) _rewardRow(context, reward),
                    ],
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 16,
                    children: [
                      for (final own in [true, false])
                        if (rewards.any(
                          (reward) =>
                              _controller.isManageable(reward.id) == own,
                        ))
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            spacing: 8,
                            children: [
                              Text(
                                own
                                    ? l10n.twitch_rewards_owned
                                    : l10n.twitch_rewards_other,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: theme.textColorSecondary,
                                ),
                              ),
                              for (final reward in rewards.where(
                                (reward) =>
                                    _controller.isManageable(reward.id) == own,
                              ))
                                _rewardRow(context, reward),
                            ],
                          ),
                    ],
                  ),
              ]),
            ],
          ],
        ),
      );
    },
  );

  Widget _card(ThemeData theme, List<Widget> children) => Container(
    decoration: theme.cardDecoration,
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );

  Widget _rewardRow(BuildContext context, RedemptionDto reward) {
    final theme = Theme.of(context);
    final l10n = context.localizations;
    final selected = reward.id == _selectedId;
    final linkedHere =
        widget.target.twitchRewardId == reward.id &&
        widget.target.twitchBroadcasterId == _controller.shared.broadcasterId;
    final configured = _hasReactions(reward);
    final status = linkedHere
        ? l10n.twitch_rewards_linked_here
        : configured
        ? l10n.twitch_rewards_configured
        : l10n.twitch_rewards_without_reactions;
    final editable = _controller.canEdit(reward.id) && !_controller.authorizing;
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final showStatusText = constraints.maxWidth >= 760 && scale <= 1.3;
        final compactControls = constraints.maxWidth < 420 || scale > 1.4;
        final radius = BorderRadius.circular(8);
        return Semantics(
          key: selected ? _selectedRow : null,
          selected: selected,
          child: Material(
            key: ValueKey('twitch-reward-row-${reward.id}'),
            color: selected ? theme.accentSubtle : theme.surfaceTertiary,
            shape: RoundedRectangleBorder(
              borderRadius: radius,
              side: BorderSide(
                color: selected ? theme.accentColor : theme.border,
                width: selected ? 1.0 : .5,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              borderRadius: radius,
              onTap: () => setState(() {
                _selectedId = reward.id;
                _selectionError = null;
              }),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    SimpleIcon.simpleSquare(
                      selected ? OutlineIcons.radioOn : OutlineIcons.radioOff,
                      size: 16,
                      color: selected
                          ? theme.accentColor
                          : theme.textColorSecondary,
                    ),
                    const Gap(10),
                    Expanded(
                      child: Text(
                        reward.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: theme.textColorPrimary,
                        ),
                      ),
                    ),
                    const Gap(10),
                    SimpleIndicator(
                      key: ValueKey('twitch-reward-price-${reward.id}'),
                      text: l10n.x_points(reward.cost),
                      theme: theme,
                      style: IndicatorStyle.neutral,
                    ),
                    const Gap(8),
                    if (showStatusText)
                      SimpleIndicator(
                        text: status,
                        theme: theme,
                        style: linkedHere
                            ? IndicatorStyle.bold
                            : IndicatorStyle.outlined,
                      )
                    else
                      Tooltip(
                        message: status,
                        child: SimpleIcon.simpleSquare(
                          linkedHere
                              ? OutlineIcons.link
                              : configured
                              ? OutlineIcons.reactions
                              : OutlineIcons.addReaction,
                          size: 16,
                          color: linkedHere
                              ? theme.accentColor
                              : theme.textColorSecondary,
                        ),
                      ),
                    const Gap(8),
                    if (_controller.isManageable(reward.id))
                      if (compactControls)
                        Tooltip(
                          message: l10n.twitch_rewards_edit,
                          child: RippleIcon(
                            icon: Assets.assetsIcSettingsWhite16dp,
                            size: 16,
                            color: theme.textColorPrimary,
                            onTap: editable ? () => _openEditor(reward) : null,
                          ),
                        )
                      else
                        CustomButton(
                          text: l10n.twitch_rewards_edit,
                          prefixIcon: Assets.assetsIcSettingsWhite16dp,
                          style: CustomButtonStyle.secondary,
                          theme: theme,
                          onTap: editable ? () => _openEditor(reward) : null,
                        )
                    else
                      Tooltip(
                        message: l10n.twitch_rewards_view_only,
                        child: SimpleIcon.simpleSquare(
                          OutlineIcons.lock,
                          size: 16,
                          color: theme.textColorSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
