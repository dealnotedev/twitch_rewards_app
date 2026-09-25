import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import 'buttons.dart';
import 'extensions.dart';
import 'generated/assets.dart';
import 'music/music_requests.dart';
import 'reward.dart';
import 'reward_executor.dart';
import 'ripple_icon.dart';
import 'simple_icon.dart';
import 'text_field_decoration.dart';
import 'themes.dart';

/// Manual tests need the same viewer input that a real redemption carries.
Future<void> testReward(
    BuildContext context, Reward reward, RewardExecutor executor) async {
  String? input;
  if (reward.handlers
      .any((a) => !a.disabled && a.type == RewardAction.typeQueueTrack)) {
    input = await showDialog<String>(
        context: context, builder: (_) => const _TrackInputDialog());
    if (input == null || !context.mounted) return;
  }
  await executor.execute(reward, userInput: input);
}

class _TrackInputDialog extends StatefulWidget {
  const _TrackInputDialog();

  @override
  State<_TrackInputDialog> createState() => _TrackInputDialogState();
}

class _TrackInputDialogState extends State<_TrackInputDialog> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _invalid = false;

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (MusicRequestManager.parseYoutubeUrl(_controller.text) == null) {
      setState(() => _invalid = true);
      _focusNode.requestFocus();
      return;
    }
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final l = context.localizations;
    final theme = Theme.of(context);
    return Dialog(
      backgroundColor: theme.surfaceSecondary,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: theme.border, width: 0.5),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 448),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                SimpleIcon.simpleSquare('assets/ic_youtube_white_16dp.svg',
                    size: 16, color: theme.textColorPrimary),
                const Gap(8),
                Expanded(
                  child: Text(l.music_test_title,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: theme.textColorPrimary)),
                ),
                const Gap(8),
                Semantics(
                  label: MaterialLocalizations.of(context).closeButtonLabel,
                  button: true,
                  child: RippleIcon(
                    icon: Assets.assetsIcCloseWhite16dp,
                    size: 16,
                    borderRadius: BorderRadius.circular(8),
                    color: theme.textColorPrimary,
                    onTap: () => Navigator.pop(context),
                  ),
                ),
              ]),
              const Gap(16),
              Text(l.music_youtube_url,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: theme.textColorPrimary)),
              const Gap(8),
              Semantics(
                label: l.music_youtube_url,
                child: TextFieldDecoration(
                  theme: theme,
                  controller: _controller,
                  focusNode: _focusNode,
                  hint: 'https://www.youtube.com/watch?v=...',
                  builder: (context, decoration, style) => TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    autofocus: true,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.done,
                    autocorrect: false,
                    enableSuggestions: false,
                    style: style,
                    decoration: decoration,
                    onChanged: (_) {
                      if (_invalid) setState(() => _invalid = false);
                    },
                    onSubmitted: (_) => _submit(),
                  ),
                ),
              ),
              if (_invalid) ...[
                const Gap(8),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.error_outline_rounded,
                      size: 16, color: theme.colorScheme.error),
                  const Gap(8),
                  Expanded(
                      child: Text(l.music_invalid_url,
                          style: TextStyle(
                              fontSize: 12, color: theme.colorScheme.error))),
                ]),
              ],
              const Gap(16),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                CustomButton(
                  theme: theme,
                  text: MaterialLocalizations.of(context).cancelButtonLabel,
                  style: CustomButtonStyle.secondary,
                  onTap: () => Navigator.pop(context),
                ),
                const Gap(8),
                CustomButton(
                  theme: theme,
                  text: l.music_test_run,
                  prefixIcon: Assets.assetsIcPlayWhite16dp,
                  style: CustomButtonStyle.primary,
                  onTap: _submit,
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
