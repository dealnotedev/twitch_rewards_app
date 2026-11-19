import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:twitch_listener/core/extensions.dart';
import 'package:twitch_listener/l10n/app_localizations.dart';
import 'package:twitch_listener/music/music_hotkey_controller.dart';
import 'package:twitch_listener/music/player_shortcut.dart';
import 'package:twitch_listener/ui/buttons.dart';
import 'package:twitch_listener/ui/key_combination_field.dart';
import 'package:twitch_listener/ui/shortcut_recording_dialog.dart';
import 'package:twitch_listener/ui/themes.dart';

class PlayerShortcutSettings extends StatefulWidget {
  final MusicHotkeyController hotkey;

  const PlayerShortcutSettings({super.key, required this.hotkey});

  @override
  State<PlayerShortcutSettings> createState() => _PlayerShortcutSettingsState();
}

class _PlayerShortcutSettingsState extends State<PlayerShortcutSettings> {
  MusicHotkeyResult? _error;
  bool _changing = false;

  Future<void> _edit() async {
    final hotkey = widget.hotkey;
    final strings = context.localizations;
    setState(() => _error = null);
    await ShortcutRecordingDialog.show(
      context,
      title: strings.player_shortcut_dialog,
      describeKeys: (keys) =>
          PlayerShortcut.tryCreate(keys)?.labels ?? const [],
      onSave: (keys) async => _errorMessage(
        strings,
        await hotkey.change(PlayerShortcut.tryCreate(keys)!),
      ),
    );
  }

  Future<void> _change(PlayerShortcut? shortcut) async {
    setState(() {
      _changing = true;
      _error = null;
    });
    final result = await widget.hotkey.change(shortcut);
    if (!mounted) return;
    setState(() {
      _changing = false;
      _error = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.localizations;
    final theme = Theme.of(context);
    final hotkey = widget.hotkey;
    return ListenableBuilder(
      listenable: hotkey,
      builder: (context, _) {
        final shortcut = hotkey.shortcut;
        final error =
            _errorMessage(strings, _error) ??
            (hotkey.registrationFailed
                ? strings.player_shortcut_inactive
                : null);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.player_shortcut_play_pause,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.textColorPrimary,
              ),
            ),
            const Gap(4),
            Text(
              strings.player_shortcut_description,
              style: TextStyle(fontSize: 12, color: theme.textColorSecondary),
            ),
            const Gap(12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: KeyCombinationField(
                keys: shortcut?.labels ?? const [],
                placeholder: strings.player_shortcut_unassigned,
              ),
            ),
            const Gap(8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                CustomButton(
                  theme: theme,
                  style: CustomButtonStyle.primary,
                  text: shortcut == null
                      ? strings.player_shortcut_assign
                      : strings.player_shortcut_change,
                  onTap: _changing ? null : _edit,
                ),
                if (shortcut != null) ...[
                  if (hotkey.registrationFailed)
                    CustomButton(
                      theme: theme,
                      style: CustomButtonStyle.secondary,
                      text: strings.player_shortcut_retry,
                      onTap: _changing ? null : () => _change(shortcut),
                    ),
                  CustomButton(
                    theme: theme,
                    style: CustomButtonStyle.secondary,
                    text: strings.player_shortcut_remove,
                    onTap: _changing ? null : () => _change(null),
                  ),
                ],
              ],
            ),
            if (error != null) ...[const Gap(8), ShortcutError(error)],
          ],
        );
      },
    );
  }
}

String? _errorMessage(AppLocalizations strings, MusicHotkeyResult? result) =>
    switch (result) {
      MusicHotkeyResult.unavailable => strings.player_shortcut_unavailable,
      MusicHotkeyResult.saveFailed => strings.player_shortcut_save_failed,
      _ => null,
    };
