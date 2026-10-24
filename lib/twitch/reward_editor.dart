import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:twitch_listener/app_router.dart';
import 'package:twitch_listener/buttons.dart';
import 'package:twitch_listener/extensions.dart';
import 'package:twitch_listener/generated/assets.dart';
import 'package:twitch_listener/themes.dart';
import 'package:twitch_listener/simple_widgets.dart';
import 'package:twitch_listener/twitch/reward_color_picker.dart';
import 'package:twitch_listener/twitch/reward_form_field.dart';
import 'package:twitch_listener/twitch/dto.dart';
import 'package:twitch_listener/twitch/reward_page.dart';
import 'package:twitch_listener/twitch/reward_settings.dart';
import 'package:twitch_listener/twitch/rewards_controller.dart';

class TwitchRewardEditor extends StatefulWidget {
  final TwitchRewardsController controller;
  final RedemptionDto? reward;
  const TwitchRewardEditor({super.key, required this.controller, this.reward});

  @override
  State<TwitchRewardEditor> createState() => _TwitchRewardEditorState();
}

class _TwitchRewardEditorState extends State<TwitchRewardEditor> {
  final _form = GlobalKey<FormState>();
  late final String? _account;
  late final TextEditingController _title;
  late final TextEditingController _cost;
  late final TextEditingController _prompt;
  late final TextEditingController _color;
  late final TextEditingController _cooldown;
  late final TextEditingController _perStream;
  late final TextEditingController _perViewer;
  late bool _input;
  late bool _enabled;
  late bool _paused;
  late bool _skipQueue;
  bool _saving = false;
  TwitchRewardsError? _error;
  bool get _creating => widget.reward == null;

  @override
  void initState() {
    super.initState();
    _account = widget.controller.accountKey;
    final value = widget.reward == null
        ? const TwitchRewardSettings(title: '', cost: 500)
        : TwitchRewardSettings.fromReward(widget.reward!);
    _title = TextEditingController(text: value.title);
    _cost = TextEditingController(text: '${value.cost}');
    _prompt = TextEditingController(text: value.prompt);
    _color = TextEditingController(text: value.color);
    _cooldown = TextEditingController(
      text: value.cooldownSeconds?.toString() ?? '',
    );
    _perStream = TextEditingController(
      text: value.maxPerStream?.toString() ?? '',
    );
    _perViewer = TextEditingController(
      text: value.maxPerUserPerStream?.toString() ?? '',
    );
    _input = value.inputRequired;
    _enabled = value.enabled;
    _paused = value.paused;
    _skipQueue = value.skipRequestQueue;
  }

  @override
  void dispose() {
    for (final field in [
      _title,
      _cost,
      _prompt,
      _color,
      _cooldown,
      _perStream,
      _perViewer,
    ]) {
      field.dispose();
    }
    super.dispose();
  }

  String? _positive(String? text, {bool optional = false, int? maximum}) {
    if (optional && (text ?? '').trim().isEmpty) return null;
    final value = int.tryParse((text ?? '').trim());
    if (value == null || value < 1 || (maximum != null && value > maximum)) {
      return maximum != null
          ? context.localizations.twitch_rewards_cooldown_invalid
          : context.localizations.twitch_rewards_positive;
    }
    return null;
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await widget.controller.saveReward(
        TwitchRewardSettings(
          title: _title.text.trim(),
          cost: int.parse(_cost.text.trim()),
          prompt: _prompt.text,
          color: _color.text.trim().toUpperCase(),
          inputRequired: _input,
          enabled: _enabled,
          paused: _paused,
          skipRequestQueue: _skipQueue,
          cooldownSeconds: int.tryParse(_cooldown.text.trim()),
          maxPerStream: int.tryParse(_perStream.text.trim()),
          maxPerUserPerStream: int.tryParse(_perViewer.text.trim()),
        ),
        id: widget.reward?.id,
        expectedAccount: _account,
      );
      if (!mounted) return;
      // Re-enable the route's pop after PopScope observes the completed save.
      setState(() => _saving = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context, result);
      });
    } catch (exception) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = TwitchRewardsController.classifyError(exception);
        });
      }
    }
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    String? Function(String?)? validator,
    int? maxLength,
    int lines = 1,
    bool numeric = false,
    TextInputAction? textInputAction,
  }) => RewardFormField(
    controller: controller,
    label: label,
    enabled: !_saving,
    validator: validator,
    maxLength: maxLength,
    lines: lines,
    numeric: numeric,
    textInputAction: textInputAction,
  );

  Widget _card(ThemeData theme, List<Widget> children) => Container(
    decoration: theme.cardDecoration,
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final theme = Theme.of(context);
      final l10n = context.localizations;
      final accountChanged = _account != widget.controller.accountKey;
      final allowed =
          !accountChanged &&
          widget.controller.canManage &&
          (_creating || widget.controller.canEdit(widget.reward!.id));
      final heading = TextStyle(fontSize: 14, color: theme.textColorPrimary);
      return PopScope(
        canPop: !_saving,
        child: TwitchRewardPage(
          title: _creating
              ? l10n.twitch_rewards_create_title
              : l10n.twitch_rewards_edit_title,
          onBack: _saving ? null : () => ApplicationRouter.pop(context),
          actions: [
            CustomButton(
              text: l10n.twitch_rewards_save,
              prefixIcon: Assets.assetsIcSaveWhite16dp,
              style: CustomButtonStyle.primary,
              theme: theme,
              loading: _saving,
              onTap: allowed && !_saving ? _save : null,
            ),
          ],
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null || !allowed) ...[
                  Text(
                    twitchRewardsErrorMessage(
                      context,
                      _error ??
                          (accountChanged
                              ? TwitchRewardsError.accountChanged
                              : !widget.controller.canManage
                              ? TwitchRewardsError.authorization
                              : TwitchRewardsError.forbidden),
                    ),
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                  const Gap(16),
                ],
                _card(theme, [
                  Text(l10n.reward_configigure_basic_settings, style: heading),
                  const Gap(8),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final title = _field(
                        _title,
                        l10n.reward_name_title,
                        maxLength: 45,
                        validator: (text) {
                          final title = (text ?? '').trim();
                          if (title.isEmpty) {
                            return l10n.twitch_rewards_required;
                          }
                          return null;
                        },
                      );
                      final cost = _field(
                        _cost,
                        l10n.twitch_rewards_cost,
                        numeric: true,
                        validator: _positive,
                      );
                      if (constraints.maxWidth >= 520 &&
                          MediaQuery.textScalerOf(context).scale(1) <= 1.3) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: title),
                            const Gap(8),
                            SizedBox(width: 156, child: cost),
                          ],
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [title, const Gap(8), cost],
                      );
                    },
                  ),
                  const Gap(8),
                  _field(
                    _prompt,
                    l10n.twitch_rewards_description,
                    maxLength: 200,
                    lines: 2,
                  ),
                  const Gap(8),
                  RewardSwitchField(
                    label: l10n.twitch_rewards_input,
                    value: _input,
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _input = value),
                  ),
                ]),
                const Gap(16),
                _card(theme, [
                  Text(l10n.twitch_rewards_color, style: heading),
                  const Gap(8),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _cost,
                    builder: (context, value, _) => RewardColorPicker(
                      controller: _color,
                      enabled: !_saving,
                      cost: int.tryParse(value.text.trim()) ?? 0,
                    ),
                  ),
                ]),
                const Gap(16),
                _card(theme, [
                  Text(l10n.twitch_rewards_limits, style: heading),
                  const Gap(8),
                  RewardSwitchField(
                    label: l10n.twitch_rewards_enabled,
                    value: _enabled,
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _enabled = value),
                  ),
                  const Gap(8),
                  if (!_creating) ...[
                    RewardSwitchField(
                      label: l10n.twitch_rewards_paused,
                      value: _paused,
                      onChanged: _saving
                          ? null
                          : (value) => setState(() => _paused = value),
                    ),
                    const Gap(8),
                  ],
                  RewardSwitchField(
                    label: l10n.twitch_rewards_skip_queue,
                    value: _skipQueue,
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _skipQueue = value),
                  ),
                  const Gap(16),
                  SimpleDivider(theme: theme),
                  const Gap(16),
                  _field(
                    _cooldown,
                    l10n.twitch_rewards_cooldown,
                    numeric: true,
                    validator: (value) =>
                        _positive(value, optional: true, maximum: 604800),
                  ),
                  const Gap(8),
                  _field(
                    _perStream,
                    l10n.twitch_rewards_per_stream,
                    numeric: true,
                    validator: (value) => _positive(value, optional: true),
                  ),
                  const Gap(8),
                  _field(
                    _perViewer,
                    l10n.twitch_rewards_per_viewer,
                    numeric: true,
                    textInputAction: TextInputAction.done,
                    validator: (value) => _positive(value, optional: true),
                  ),
                ]),
              ],
            ),
          ),
        ),
      );
    },
  );
}
