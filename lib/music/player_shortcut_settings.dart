import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:twitch_listener/core/extensions.dart';
import 'package:twitch_listener/l10n/app_localizations.dart';
import 'package:twitch_listener/music/music_hotkey_controller.dart';
import 'package:twitch_listener/music/player_shortcut.dart';
import 'package:twitch_listener/ui/buttons.dart';
import 'package:twitch_listener/ui/key_combination_field.dart';
import 'package:twitch_listener/ui/themes.dart';
import 'package:win32/win32.dart';

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
    setState(() => _error = null);
    hotkey.recording = true;
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _ShortcutDialog(hotkey: hotkey),
      );
    } finally {
      hotkey.recording = false;
    }
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
            if (error != null) ...[const Gap(8), _ShortcutError(error)],
          ],
        );
      },
    );
  }
}

class _ShortcutDialog extends StatefulWidget {
  final MusicHotkeyController hotkey;

  const _ShortcutDialog({required this.hotkey});

  @override
  State<_ShortcutDialog> createState() => _ShortcutDialogState();
}

class _ShortcutDialogState extends State<_ShortcutDialog> {
  PlayerShortcut? _candidate;
  MusicHotkeyResult? _error;
  bool _invalid = false;
  bool _saving = false;

  Future<void> _save() async {
    final shortcut = _candidate;
    if (shortcut == null || _saving) return;
    setState(() => _saving = true);
    final result = await widget.hotkey.change(shortcut);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _error = result;
    });
    if (result == MusicHotkeyResult.saved) Navigator.of(context).pop();
  }

  // Use the focused Windows event's virtual key to preserve the keyboard layout
  // and match RegisterHotKey. KeyEvent does not expose that native code.
  // ignore: deprecated_member_use
  KeyEventResult _capture(FocusNode node, RawKeyEvent event) {
    final data = event.data;
    // ignore: deprecated_member_use
    if (event is! RawKeyDownEvent || data is! RawKeyEventDataWindows) {
      return KeyEventResult.ignored;
    }
    final key = data.keyCode;
    if (key == VK_ESCAPE) {
      if (!_saving) Navigator.of(context).pop();
      return KeyEventResult.handled;
    }
    final keyboard = HardwareKeyboard.instance;
    final modifiers =
        (keyboard.isControlPressed ? MOD_CONTROL : 0) |
        (keyboard.isAltPressed ? MOD_ALT : 0) |
        (keyboard.isShiftPressed ? MOD_SHIFT : 0);
    if (modifiers & (MOD_CONTROL | MOD_ALT) == 0 && key == VK_TAB) {
      return KeyEventResult.ignored;
    }
    if (_saving || event.repeat || PlayerShortcut.isModifierKey(key)) {
      return KeyEventResult.handled;
    }
    if (modifiers == 0 && (key == VK_RETURN || key == VK_SPACE)) {
      if (!node.hasPrimaryFocus) return KeyEventResult.ignored;
      if (key == VK_RETURN && _candidate != null) {
        _save();
        return KeyEventResult.handled;
      }
    }
    final candidate = keyboard.isMetaPressed
        ? null
        : PlayerShortcut.tryCreate(key, modifiers);
    setState(() {
      _candidate = candidate;
      _error = null;
      _invalid = candidate == null;
    });
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = context.localizations;
    final error = _invalid
        ? strings.player_shortcut_invalid
        : _errorMessage(strings, _error);
    return Focus(
      autofocus: true,
      // ignore: deprecated_member_use
      onKey: _capture,
      child: PopScope(
        canPop: !_saving,
        child: AlertDialog(
          scrollable: true,
          title: Text(strings.player_shortcut_dialog),
          content: SizedBox(
            width: 340,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(strings.player_shortcut_recording_help),
                const Gap(12),
                Semantics(
                  liveRegion: true,
                  child: KeyCombinationField(
                    keys: _candidate?.labels ?? const [],
                    placeholder: strings.player_shortcut_recording,
                    recording: true,
                  ),
                ),
                if (error != null) ...[const Gap(8), _ShortcutError(error)],
              ],
            ),
          ),
          actions: [
            CustomButton(
              theme: theme,
              style: CustomButtonStyle.secondary,
              text: MaterialLocalizations.of(context).cancelButtonLabel,
              onTap: _saving ? null : () => Navigator.of(context).pop(),
            ),
            CustomButton(
              theme: theme,
              style: CustomButtonStyle.primary,
              text: strings.button_save_changes,
              loading: _saving,
              onTap: _saving || _candidate == null ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}

String? _errorMessage(AppLocalizations strings, MusicHotkeyResult? result) =>
    switch (result) {
      MusicHotkeyResult.unavailable => strings.player_shortcut_unavailable,
      MusicHotkeyResult.saveFailed => strings.player_shortcut_save_failed,
      _ => null,
    };

class _ShortcutError extends StatelessWidget {
  final String message;

  const _ShortcutError(this.message);

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Text(
      message,
      style: TextStyle(
        fontSize: 12,
        color: Theme.of(context).colorScheme.error,
      ),
    ),
  );
}
