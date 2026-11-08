import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:twitch_listener/app/app_router.dart';
import 'package:twitch_listener/core/extensions.dart';
import 'package:twitch_listener/points/viewer_balances_store.dart';
import 'package:twitch_listener/rewards/reward.dart';
import 'package:twitch_listener/ui/integer_input_formatter.dart';
import 'package:twitch_listener/ui/text_field_decoration.dart';
import 'package:twitch_listener/ui/themes.dart';

class CreditPointsWidget extends StatefulWidget {
  final RewardAction action;
  final VoidCallback changesCallback;

  const CreditPointsWidget({
    super.key,
    required this.action,
    required this.changesCallback,
  });

  @override
  State<CreditPointsWidget> createState() => _CreditPointsWidgetState();
}

class _CreditPointsWidgetState extends State<CreditPointsWidget> {
  late final _controller = TextEditingController(
    text: widget.action.pointsAmount?.toString() ?? '',
  );
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged() {
    final text = _controller.text;
    final amount = text.isEmpty ? null : int.parse(text);
    if (widget.action.pointsAmount == amount) return;
    widget.action.pointsAmount = amount;
    widget.changesCallback();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.localizations;
    final description = l10n
        .reaction_credit_points_description('\uFFFC')
        .split('\uFFFC');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.reaction_credit_points_amount,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: theme.textColorPrimary,
          ),
        ),
        const Gap(8),
        Semantics(
          label: l10n.reaction_credit_points_amount,
          child: TextFieldDecoration(
            controller: _controller,
            focusNode: _focusNode,
            theme: theme,
            hint: l10n.reaction_credit_points_hint,
            builder: (context, decoration, style) => TextField(
              key: const ValueKey('credit-points-amount'),
              controller: _controller,
              focusNode: _focusNode,
              keyboardType: const TextInputType.numberWithOptions(
                signed: false,
                decimal: false,
              ),
              inputFormatters: const [
                UnsignedIntegerInputFormatter(
                  maxValue: ViewerBalancesStore.maxBalance,
                ),
              ],
              textInputAction: TextInputAction.done,
              autocorrect: false,
              enableSuggestions: false,
              style: style,
              decoration: decoration,
            ),
          ),
        ),
        const Gap(8),
        Text.rich(
          TextSpan(
            text: description.first,
            children: [
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: Semantics(
                  link: true,
                  child: TextButton(
                    key: const ValueKey('credit-points-balances-link'),
                    onPressed: () =>
                        ApplicationRouter.openViewerBalances(context),
                    style: TextButton.styleFrom(
                      foregroundColor: theme.accentColor,
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: const TextStyle(
                        fontSize: 12,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    child: Text(l10n.reaction_credit_points_balance_link),
                  ),
                ),
              ),
              TextSpan(text: description.last),
            ],
          ),
          style: TextStyle(fontSize: 12, color: theme.textColorSecondary),
        ),
      ],
    );
  }
}
