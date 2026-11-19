import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:twitch_listener/core/extensions.dart';
import 'package:twitch_listener/core/windows_keyboard.dart';
import 'package:twitch_listener/ui/buttons.dart';
import 'package:twitch_listener/ui/key_combination_field.dart';
import 'package:win32/win32.dart';

class ShortcutRecordingDialog extends StatefulWidget {
  final String title;
  final Iterable<String> Function(Iterable<int>)? describeKeys;
  final Future<String?> Function(List<int>)? onSave;

  const ShortcutRecordingDialog._({
    required this.title,
    this.describeKeys,
    this.onSave,
  });

  static Future<List<int>?> show(
    BuildContext context, {
    required String title,
    Iterable<String> Function(Iterable<int>)? describeKeys,
    Future<String?> Function(List<int>)? onSave,
  }) => ShortcutRecording.run(
    () => showDialog<List<int>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ShortcutRecordingDialog._(
        title: title,
        describeKeys: describeKeys,
        onSave: onSave,
      ),
    ),
  );

  @override
  State<ShortcutRecordingDialog> createState() =>
      _ShortcutRecordingDialogState();
}

class _ShortcutRecordingDialogState extends State<ShortcutRecordingDialog> {
  final _focus = FocusNode();
  final _held = <PhysicalKeyboardKey>{};
  final _keys = <int>{};
  late final AppLifecycleListener _lifecycle;
  String? _error;
  bool _capturing = true;
  bool _released = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onInactive: () {
        if (_capturing && _held.isNotEmpty) _startCapture();
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _startCapture() {
    setState(() {
      _held.clear();
      _keys.clear();
      _error = null;
      _released = false;
      _capturing = true;
    });
    _focus.requestFocus();
  }

  Future<void> _save() async {
    if (_saving || _capturing || _keys.isEmpty) return;
    setState(() => _saving = true);
    final keys = List<int>.unmodifiable(_keys);
    final error = await widget.onSave?.call(keys);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _error = error;
    });
    if (error == null) Navigator.of(context).pop(keys);
  }

  // The Windows virtual key preserves the keyboard layout and can be used
  // directly by SendInput. KeyEvent does not carry this code.
  // ignore: deprecated_member_use
  KeyEventResult _capture(FocusNode node, RawKeyEvent event) {
    final data = event.data;
    // ignore: deprecated_member_use
    if (data is! RawKeyEventDataWindows) return KeyEventResult.ignored;
    final key = data.keyCode;
    // ignore: deprecated_member_use
    final down = event is RawKeyDownEvent;
    if (!_capturing || !node.hasPrimaryFocus) {
      if (down && key == VK_ESCAPE) {
        if (!_saving) Navigator.of(context).pop();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (down) {
      if (!event.repeat &&
          isWindowsKeyboardKey(key) &&
          _held.add(event.physicalKey) &&
          !_released) {
        setState(() => _keys.add(key));
      }
    } else if (_held.remove(event.physicalKey)) {
      _released = true;
      if (_held.isEmpty) {
        if (_keys.length == 1 && _keys.contains(VK_ESCAPE)) {
          Navigator.of(context).pop();
          return KeyEventResult.handled;
        }
        setState(() => _capturing = false);
      }
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = context.localizations;
    final error = _error;
    final labels =
        widget.describeKeys?.call(_keys) ?? _keys.map(windowsShortcutKeyLabel);
    return Focus(
      focusNode: _focus,
      autofocus: true,
      // ignore: deprecated_member_use
      onKey: _capture,
      child: PopScope(
        canPop: !_saving,
        child: AlertDialog(
          scrollable: true,
          title: Text(widget.title),
          content: SizedBox(
            width: 340,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(strings.shortcut_recording_help),
                const Gap(12),
                Semantics(
                  liveRegion: true,
                  child: KeyCombinationField(
                    keys: labels,
                    placeholder: strings.shortcut_recording,
                  ),
                ),
                if (error != null) ...[const Gap(8), ShortcutError(error)],
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
            if (!_capturing)
              CustomButton(
                theme: theme,
                style: CustomButtonStyle.secondary,
                text: strings.shortcut_record_again,
                onTap: _saving ? null : _startCapture,
              ),
            CustomButton(
              theme: theme,
              style: CustomButtonStyle.primary,
              text: strings.button_save_changes,
              loading: _saving,
              onTap: _saving || _capturing || _keys.isEmpty ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}

class ShortcutError extends StatelessWidget {
  final String message;

  const ShortcutError(this.message, {super.key});

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
