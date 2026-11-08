import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:twitch_listener/app/app_router.dart';
import 'package:twitch_listener/core/extensions.dart';
import 'package:twitch_listener/generated/assets.dart';
import 'package:twitch_listener/points/viewer_balance.dart';
import 'package:twitch_listener/points/viewer_balances_store.dart';
import 'package:twitch_listener/ui/app_page.dart';
import 'package:twitch_listener/ui/buttons.dart';
import 'package:twitch_listener/ui/outline_icons.dart';
import 'package:twitch_listener/ui/simple_icon.dart';
import 'package:twitch_listener/ui/simple_indicator.dart';
import 'package:twitch_listener/ui/simple_widgets.dart';
import 'package:twitch_listener/ui/text_field_decoration.dart';
import 'package:twitch_listener/ui/themes.dart';

class ViewerBalancesScreen extends StatefulWidget {
  final ViewerBalancesStore store;

  const ViewerBalancesScreen({super.key, required this.store});

  @override
  State<ViewerBalancesScreen> createState() => _ViewerBalancesScreenState();
}

class _ViewerBalancesScreenState extends State<ViewerBalancesScreen> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  final _verticalScroll = ScrollController();
  late final StreamSubscription<void> _changes;
  List<ViewerBalance> _balances = [];
  bool _loading = false;
  bool _failed = false;
  bool _reloadQueued = false;

  @override
  void initState() {
    super.initState();
    _search.addListener(_searchChanged);
    _changes = widget.store.changes.listen((_) => unawaited(_reload()));
    unawaited(_reload());
  }

  @override
  void dispose() {
    unawaited(_changes.cancel());
    _search.removeListener(_searchChanged);
    _search.dispose();
    _searchFocus.dispose();
    _verticalScroll.dispose();
    super.dispose();
  }

  void _searchChanged() {
    if (_verticalScroll.hasClients) _verticalScroll.jumpTo(0);
    setState(() {});
  }

  Future<void> _reload() async {
    // Coalesce writes during a query, then read again so an older result can
    // never leave an open screen showing a balance from before a commit.
    _reloadQueued = true;
    if (_loading) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    while (mounted && _reloadQueued) {
      _reloadQueued = false;
      try {
        final balances = await widget.store.loadBalances();
        if (!mounted) return;
        setState(() {
          _balances = balances;
          _failed = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() => _failed = true);
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.localizations;
    final displayed = _balances
        .where((row) => row.matches(_search.text))
        .toList();
    return AppPage(
      title: l10n.viewer_balances_title,
      onBack: () => ApplicationRouter.pop(context),
      scrollable: false,
      actions: [
        CustomButton(
          text: l10n.viewer_balances_refresh,
          prefixIcon: OutlineIcons.refresh,
          style: CustomButtonStyle.secondary,
          theme: theme,
          loading: _loading,
          onTap: _loading ? null : _reload,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            label: l10n.viewer_balances_search,
            child: TextFieldDecoration(
              theme: theme,
              controller: _search,
              focusNode: _searchFocus,
              hint: l10n.viewer_balances_search,
              prefix: SimpleIcon.simpleSquare(
                Assets.assetsIcSearchWhite16dp,
                size: 16,
                color: theme.textColorSecondary,
              ),
              builder: (context, decoration, style) => TextField(
                key: const ValueKey('viewer-balances-search'),
                controller: _search,
                focusNode: _searchFocus,
                textInputAction: TextInputAction.search,
                autocorrect: false,
                enableSuggestions: false,
                decoration: decoration,
                style: style,
              ),
            ),
          ),
          const Gap(12),
          if (!_failed) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: SimpleIndicator(
                text: l10n.viewer_balances_count(
                  displayed.length,
                  _balances.length,
                ),
                theme: theme,
                style: IndicatorStyle.neutral,
              ),
            ),
            const Gap(12),
          ],
          Expanded(child: _body(context, displayed)),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, List<ViewerBalance> displayed) {
    final theme = Theme.of(context);
    final l10n = context.localizations;
    if (_loading && _balances.isEmpty && !_failed) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_failed || displayed.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Text(
            _failed
                ? l10n.viewer_balances_error
                : _balances.isEmpty
                ? l10n.viewer_balances_empty
                : l10n.viewer_balances_no_matches,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: _failed
                  ? theme.colorScheme.error
                  : theme.textColorSecondary,
            ),
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final idWidth = (constraints.maxWidth * 0.2)
            .clamp(72.0, 120.0)
            .toDouble();
        final balanceWidth = (constraints.maxWidth * 0.25)
            .clamp(96.0, 180.0)
            .toDouble();
        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: theme.cardDecoration,
          child: Column(
            children: [
              Semantics(
                header: true,
                child: Container(
                  color: theme.surfaceTertiary,
                  child: _row(
                    context,
                    id: l10n.viewer_balances_id,
                    name: TextSpan(text: l10n.viewer_balances_name),
                    balance: l10n.viewer_balances_balance,
                    idWidth: idWidth,
                    balanceWidth: balanceWidth,
                    header: true,
                  ),
                ),
              ),
              SimpleDivider(theme: theme),
              Expanded(
                child: Scrollbar(
                  controller: _verticalScroll,
                  thumbVisibility: true,
                  child: ListView.separated(
                    key: const ValueKey('viewer-balances-rows'),
                    controller: _verticalScroll,
                    itemCount: displayed.length,
                    separatorBuilder: (_, _) => SimpleDivider(theme: theme),
                    itemBuilder: (context, index) {
                      final balance = displayed[index];
                      return Semantics(
                        key: ValueKey('viewer-balance-${balance.viewerId}'),
                        container: true,
                        child: _row(
                          context,
                          id: balance.viewerId,
                          name: _viewerName(context, balance),
                          balance: balance.balance.toString(),
                          idWidth: idWidth,
                          balanceWidth: balanceWidth,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  TextSpan _viewerName(BuildContext context, ViewerBalance viewer) {
    return TextSpan(
      text: viewer.displayName.isEmpty && viewer.username.isEmpty
          ? '—'
          : viewer.displayName,
      children: [
        if (viewer.username.isNotEmpty)
          TextSpan(
            text: viewer.displayName.isEmpty
                ? '@${viewer.username}'
                : ' (@${viewer.username})',
            style: TextStyle(
              color: Theme.of(context).accentColor,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }

  Widget _row(
    BuildContext context, {
    required String id,
    required TextSpan name,
    required String balance,
    required double idWidth,
    required double balanceWidth,
    bool header = false,
  }) {
    final theme = Theme.of(context);
    final style = TextStyle(
      fontSize: header ? 12 : 13,
      fontWeight: header ? FontWeight.w600 : FontWeight.w400,
      color: header ? theme.textColorSecondary : theme.textColorPrimary,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: idWidth,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(id, maxLines: 1, style: style),
            ),
          ),
          const Gap(12),
          Expanded(
            child: Text.rich(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
          const Gap(12),
          SizedBox(
            width: balanceWidth,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                balance,
                maxLines: 1,
                style: style.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
