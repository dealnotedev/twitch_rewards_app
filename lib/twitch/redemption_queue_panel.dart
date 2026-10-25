import 'dart:async';

import 'package:flutter/material.dart';
import 'package:twitch_listener/ui/buttons.dart';
import 'package:twitch_listener/core/extensions.dart';
import 'package:twitch_listener/generated/assets.dart';
import 'package:twitch_listener/ui/outline_icons.dart';
import 'package:twitch_listener/ui/simple_icon.dart';
import 'package:twitch_listener/ui/simple_indicator.dart';
import 'package:twitch_listener/ui/themes.dart';

import 'redemption.dart';
import 'redemption_queue_controller.dart';
import 'redemption_queue_entry.dart';
import 'rewards_controller.dart';

class RedemptionQueuePanel extends StatefulWidget {
  final RedemptionQueueController controller;
  const RedemptionQueuePanel({super.key, required this.controller});

  @override
  State<RedemptionQueuePanel> createState() => _RedemptionQueuePanelState();
}

class _RedemptionQueuePanelState extends State<RedemptionQueuePanel> {
  static const _departureDuration = Duration(milliseconds: 540);
  static const _departureVisibleDuration = Duration(milliseconds: 320);
  static const _reflowDuration = Duration(milliseconds: 220);
  GlobalKey<AnimatedListState> _listKey = GlobalKey();
  final _visible = <RedemptionQueueEntry>[];
  Timer? _clock;
  String? _account;
  int _departures = 0;
  int _epoch = 0;

  @override
  void initState() {
    super.initState();
    _account = widget.controller.accountKey;
    _visible.addAll(widget.controller.entries);
    widget.controller.addListener(_changed);
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_visible.isNotEmpty && mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant RedemptionQueuePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
      _reset();
    }
  }

  void _reset() {
    _epoch++;
    _listKey = GlobalKey();
    _visible
      ..clear()
      ..addAll(widget.controller.entries);
    _account = widget.controller.accountKey;
    _departures = 0;
  }

  void _changed() {
    if (!mounted) return;
    if (_account != widget.controller.accountKey) {
      setState(_reset);
      return;
    }
    final entries = widget.controller.entries;
    final ids = entries.map((entry) => entry.id).toSet();
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    // Before the first frame AnimatedList will use initialItemCount.
    if (_listKey.currentState == null) {
      setState(() {
        _visible
          ..clear()
          ..addAll(entries);
      });
      return;
    }
    for (var index = _visible.length - 1; index >= 0; index--) {
      if (ids.contains(_visible[index].id)) continue;
      final removed = _visible.removeAt(index);
      if (!reducedMotion) _departures++;
      _listKey.currentState!.removeItem(
        index,
        (context, animation) => reducedMotion
            ? const SizedBox.shrink()
            : _departure(animation, _row(removed, departing: true)),
        duration: reducedMotion ? Duration.zero : _departureDuration,
      );
      if (!reducedMotion) {
        final epoch = _epoch;
        Future<void>.delayed(_departureVisibleDuration, () {
          if (mounted && epoch == _epoch) setState(() => _departures--);
        });
      }
    }
    for (var index = 0; index < entries.length; index++) {
      if (_visible.any((entry) => entry.id == entries[index].id)) continue;
      final position = index.clamp(0, _visible.length);
      _visible.insert(position, entries[index]);
      _listKey.currentState!.insertItem(
        position,
        duration: reducedMotion
            ? Duration.zero
            : const Duration(milliseconds: 260),
      );
    }
    setState(() {});
  }

  Widget _transition(Animation<double> animation, Widget child) =>
      SizeTransition(
        sizeFactor: CurvedAnimation(
          parent: animation,
          curve: const Interval(0, 0.65, curve: Curves.easeInOutCubic),
        ),
        alignment: Alignment.topCenter,
        child: FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: const Interval(0, 0.45, curve: Curves.easeOut),
          ),
          child: child,
        ),
      );

  Widget _departure(Animation<double> animation, Widget child) {
    final progress = ReverseAnimation(animation);
    final slide = progress.drive(
      CurveTween(
        curve: const Interval(120 / 540, 320 / 540, curve: Curves.easeOut),
      ),
    );
    // Close the gap only after the row has completely faded out.
    final closing = progress.drive(
      CurveTween(
        curve: const Interval(320 / 540, 1, curve: Cubic(0.2, 0.75, 0.25, 1)),
      ),
    );
    return SizeTransition(
      sizeFactor: closing.drive(Tween(begin: 1.0, end: 0.0)),
      alignment: Alignment.topCenter,
      child: FadeTransition(
        opacity: slide.drive(Tween(begin: 1.0, end: 0.0)),
        child: AnimatedBuilder(
          animation: slide,
          child: IgnorePointer(child: child),
          builder: (context, child) => Transform.translate(
            offset: Offset(28 * slide.value, 0),
            child: child,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _clock?.cancel();
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.localizations;
    final totalPoints = _visible.fold<int>(
      0,
      (sum, entry) => sum + entry.redemption.cost,
    );
    final empty =
        _visible.isEmpty &&
        _departures == 0 &&
        widget.controller.setupError == null;
    // Follow window width immediately; AnimatedSize should only animate height.
    return SizedBox(
      width: double.infinity,
      child: AnimatedSize(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : _reflowDuration,
        curve: Curves.easeInOutCubic,
        alignment: Alignment.topCenter,
        child: empty
            ? const SizedBox(width: double.infinity)
            : Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Container(
                  decoration: theme.cardDecoration,
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                SimpleIcon.simpleSquare(
                                  Assets.assetsIcClockWhite16dp,
                                  size: 16,
                                  color: theme.textColorPrimary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    l10n.redemption_queue_title,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: theme.textColorPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: [
                                SimpleIndicator(
                                  theme: theme,
                                  style: IndicatorStyle.neutral,
                                  text: l10n.x_total(_visible.length),
                                ),
                                SimpleIndicator(
                                  theme: theme,
                                  style: IndicatorStyle.outlined,
                                  text: l10n.x_points(totalPoints),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (widget.controller.setupError != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.redemption_queue_setup_error,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.error,
                                ),
                              ),
                              const SizedBox(height: 8),
                              CustomButton(
                                theme: theme,
                                style: CustomButtonStyle.secondary,
                                text:
                                    widget.controller.setupError ==
                                            TwitchRewardsError.authorization ||
                                        widget.controller.setupError ==
                                            TwitchRewardsError.forbidden
                                    ? l10n.twitch_rewards_reconnect
                                    : l10n.redemption_queue_retry,
                                onTap: () =>
                                    unawaited(widget.controller.retrySetup()),
                              ),
                            ],
                          ),
                        ),
                      AnimatedList(
                        key: _listKey,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,
                        initialItemCount: _visible.length,
                        itemBuilder: (context, index, animation) =>
                            _transition(animation, _row(_visible[index])),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  String _status(RedemptionQueueEntry entry) {
    final l10n = context.localizations;
    if (entry.terminal) {
      return entry.state == RedemptionQueueState.confirmed
          ? l10n.redemption_queue_confirmed
          : l10n.redemption_queue_refunded;
    }
    if (entry.intent != null) {
      if (entry.error != null) {
        return switch (entry.error!) {
          TwitchRewardsError.authorization ||
          TwitchRewardsError.forbidden => l10n.redemption_queue_permission,
          TwitchRewardsError.network ||
          TwitchRewardsError.rateLimited => l10n.redemption_queue_network,
          TwitchRewardsError.notFound => l10n.redemption_queue_missing,
          _ => l10n.redemption_queue_error,
        };
      }
      return entry.intent == RedemptionStatus.fulfilled
          ? l10n.redemption_queue_confirming
          : l10n.redemption_queue_refunding;
    }
    return switch (entry.state) {
      RedemptionQueueState.executing => l10n.redemption_queue_executing,
      _ =>
        _remaining(entry) <= const Duration(minutes: 1)
            ? l10n.redemption_queue_soon
            : l10n.redemption_queue_waiting,
    };
  }

  Duration _remaining(RedemptionQueueEntry entry) {
    final remaining =
        entry.confirmAt?.difference(widget.controller.now()) ?? Duration.zero;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  Widget _statusIndicator(RedemptionQueueEntry entry) {
    final theme = Theme.of(context);
    final label = _status(entry);
    final warningColor = theme.dark
        ? const Color(0xFFE8BD76)
        : const Color(0xFF95620B);
    final Widget icon;
    if (entry.terminal) {
      icon = SimpleIcon.simpleSquare(
        entry.state == RedemptionQueueState.refunded
            ? OutlineIcons.refund
            : Assets.assetsIcCheckWhite16dp,
        size: 16,
        color: theme.positiveColor,
      );
    } else if (entry.error != null) {
      icon = SimpleIcon.simpleSquare(
        Assets.assetsIcWarningWhite16dp,
        size: 16,
        color: warningColor,
      );
    } else if (entry.state == RedemptionQueueState.executing ||
        entry.intent != null) {
      icon = CircularProgressIndicator(
        strokeWidth: 1.5,
        value: MediaQuery.disableAnimationsOf(context) ? 0.75 : null,
        color: theme.accentColor,
      );
    } else {
      icon = SimpleIcon.simpleSquare(
        Assets.assetsIcCheckWhite16dp,
        size: 16,
        color: theme.positiveColor,
      );
    }
    return Semantics(
      label: label,
      image: true,
      liveRegion: true,
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: ExcludeSemantics(
          child: SizedBox(width: 16, height: 16, child: icon),
        ),
      ),
    );
  }

  Widget _row(RedemptionQueueEntry entry, {bool departing = false}) {
    final theme = Theme.of(context);
    final l10n = context.localizations;
    final finished = departing || entry.terminal;
    final waiting =
        entry.state == RedemptionQueueState.waiting && entry.intent == null;
    final showCountdown = entry.confirmAt != null;
    final remaining = _remaining(entry);
    final soon = waiting && remaining <= const Duration(minutes: 1);
    final color = finished
        ? theme.positiveColor
        : soon
        ? (theme.dark ? const Color(0xFFE8BD76) : const Color(0xFF95620B))
        : theme.accentColor;
    final identity = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipOval(
          child: SizedBox(
            width: 34,
            height: 34,
            child: entry.avatarUrl == null
                ? _avatarFallback(theme)
                : Image.network(
                    entry.avatarUrl!,
                    fit: BoxFit.cover,
                    loadingBuilder: (_, child, progress) =>
                        progress == null ? child : _avatarFallback(theme),
                    errorBuilder: (_, _, _) => _avatarFallback(theme),
                  ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 5,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    entry.redemption.userName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.textColorPrimary,
                    ),
                  ),
                  SimpleIndicator(
                    theme: theme,
                    text: l10n.x_points(entry.redemption.cost),
                    style: IndicatorStyle.neutral,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Tooltip(
                      message: entry.redemption.title,
                      child: Text(
                        entry.redemption.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.textColorPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  _statusIndicator(entry),
                ],
              ),
            ],
          ),
        ),
      ],
    );
    final meter = showCountdown
        ? _timer(remaining, finished ? theme.accentColor : color)
        : const SizedBox.shrink();
    final enabled = widget.controller.canDecide(entry);
    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (entry.intent != null && entry.error != null)
          _actionButton(
            label: l10n.redemption_queue_retry,
            icon: OutlineIcons.refresh,
            loading: widget.controller.isBusy(entry.id),
            onTap: widget.controller.isBusy(entry.id)
                ? null
                : () => unawaited(widget.controller.retry(entry.id)),
          )
        else ...[
          _actionButton(
            label: l10n.redemption_queue_confirm_now,
            icon: Assets.assetsIcCheckWhite16dp,
            loading:
                widget.controller.isBusy(entry.id) &&
                entry.intent == RedemptionStatus.fulfilled,
            onTap: enabled
                ? () => unawaited(widget.controller.confirmNow(entry.id))
                : null,
          ),
          _actionButton(
            label: l10n.redemption_queue_refund,
            icon: OutlineIcons.refund,
            loading:
                widget.controller.isBusy(entry.id) &&
                entry.intent == RedemptionStatus.canceled,
            onTap: enabled
                ? () => unawaited(widget.controller.refund(entry.id))
                : null,
          ),
        ],
      ],
    );
    return Container(
      key: ValueKey('redemption-${entry.account}-${entry.id}'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: !finished && soon
            ? Color.alphaBlend(
                color.withValues(alpha: 0.04),
                theme.surfaceTertiary,
              )
            : theme.surfaceTertiary,
        border: Border.all(
          color: theme.border,
          width: 0.5,
          strokeAlign: BorderSide.strokeAlignOutside,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final textScale = MediaQuery.textScalerOf(context).scale(1);
          final wide = constraints.maxWidth >= 520 * textScale;
          if (wide) {
            return Row(
              children: [
                Expanded(child: identity),
                const SizedBox(width: 12),
                SizedBox(width: 150 * textScale, child: meter),
                const SizedBox(width: 12),
                actions,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              identity,
              const SizedBox(height: 12),
              if (constraints.maxWidth >= 490 &&
                  MediaQuery.textScalerOf(context).scale(1) <= 1.3)
                Row(
                  children: [
                    SizedBox(width: 165, child: meter),
                    const Spacer(),
                    actions,
                  ],
                )
              else ...[
                if (showCountdown) ...[meter, const SizedBox(height: 12)],
                actions,
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required String icon,
    required VoidCallback? onTap,
    bool loading = false,
  }) => Semantics(
    label: label,
    button: true,
    enabled: onTap != null,
    child: Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: SizedBox(
        width: 40,
        height: 30,
        child: CustomButton(
          theme: Theme.of(context),
          style: CustomButtonStyle.secondary,
          text: '',
          prefixIcon: icon,
          loading: loading,
          onTap: onTap,
        ),
      ),
    ),
  );

  Widget _avatarFallback(ThemeData theme) => ColoredBox(
    color: theme.surfaceTertiary,
    child: Icon(
      Icons.person_outline_rounded,
      size: 20,
      color: theme.textColorSecondary,
    ),
  );

  Widget _timer(Duration remaining, Color color) {
    final theme = Theme.of(context);
    final l10n = context.localizations;
    final seconds = (remaining.inMilliseconds / 1000).ceil().clamp(0, 600);
    final formatted =
        '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
    return Semantics(
      label: l10n.redemption_queue_countdown(formatted),
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  l10n.redemption_queue_until,
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.textColorSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatted,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: theme.textColorPrimary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 650),
              curve: Curves.linear,
              tween: Tween(
                end:
                    (remaining.inMilliseconds /
                            RedemptionQueueController
                                .confirmationDelay
                                .inMilliseconds)
                        .clamp(0, 1),
              ),
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 4,
                backgroundColor: theme.surfaceTertiary,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
