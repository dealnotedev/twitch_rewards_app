import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:hid_listener/hid_listener.dart';
import 'package:twitch_listener/buttons.dart';
import 'package:twitch_listener/extensions.dart';
import 'package:twitch_listener/reward.dart';
import 'package:twitch_listener/rewards/keys_logger.dart';
import 'package:twitch_listener/themes.dart';

class SendInputWidget extends StatefulWidget {
  final RewardAction action;

  const SendInputWidget({super.key, required this.action});

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<SendInputWidget> {
  late final RewardAction _action;

  @override
  void initState() {
    _action = widget.action;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(children: [
      Expanded(
        child: _recording
            ? _KeylogWidget(onCompleted: _handleEntriesRecorded)
            : _createConbinationState(context, theme),
      ),
      const Gap(8),
      CustomButton(
          text: context.localizations.button_setup,
          style: CustomButtonStyle.secondary,
          theme: theme,
          onTap: _recording ? null : () => _handleSetupClick(context))
    ]);
  }

  Widget _createConbinationState(BuildContext context, ThemeData theme) {
    const radius = Radius.circular(4);

    final entries = _action.inputs;

    final TextSpan text;
    if (entries.isEmpty) {
      text = TextSpan(
          text: context.localizations.reaction_send_input_hint_default,
          style: TextStyle(fontSize: 12, color: theme.textColorSecondary));
    } else {
      text = TextSpan(
          style: TextStyle(fontSize: 12, color: theme.textColorSecondary),
          children: _createKeysSpans(entries,
              style: TextStyle(
                  color: theme.textColorPrimary, fontWeight: FontWeight.w600),
              delimiter: ' + '));
    }

    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.dividerColor, width: 0.5)),
      child: RichText(text: text),
    );
  }

  bool _recording = false;

  void _handleSetupClick(BuildContext context) {
    setState(() {
      _recording = true;
    });
  }

  void _handleEntriesRecorded(Set<InputEntry> entries) {
    setState(() {
      _recording = false;
      _action.inputs = List.of(entries);
    });
  }
}

List<TextSpan> _createKeysSpans(List<InputEntry> entries,
    {required TextStyle style, required String delimiter}) {
  final spans = <TextSpan>[];

  for (int i = 0; i < entries.length; i++) {
    final entry = entries[i];

    if (i > 0) {
      spans.add(TextSpan(text: delimiter));
    }

    spans.add(TextSpan(text: entry.name, style: style));
  }

  return spans;
}

class _KeylogWidget extends StatefulWidget {
  final void Function(Set<InputEntry> entries)? onCompleted;

  const _KeylogWidget({this.onCompleted});

  @override
  State<StatefulWidget> createState() => _KeylogState();
}

class _KeylogState extends State<_KeylogWidget> with TickerProviderStateMixin {
  _LoggerListenerPair? _logger;

  AnimationController? _controller;

  @override
  void initState() {
    final backend = KeysLogger.getReadyBackend();
    if (backend != null) {
      final listenerId = backend.addKeyboardListener((e) {
        final data = e.data;
        debugPrint(e.toString());

        if (data is RawKeyEventDataWindows) {
          _handleKeyboardEvent(
              keyCode: data.keyCode,
              keyLabel: e.logicalKey.keyLabel,
              down: e is RawKeyDownEvent);
        }
      });
      _logger = _LoggerListenerPair(backend: backend, listenerId: listenerId);
    }

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )
      ..addListener(_handleAnimationProgress)
      ..addStatusListener(_handleAnimationStatus)
      ..forward();

    super.initState();
  }

  @override
  void dispose() {
    _logger?.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final TextSpan text;
    if (_entries.isEmpty) {
      text = TextSpan(
          text: context.localizations.reaction_send_input_hint_recording,
          style: TextStyle(fontSize: 12, color: theme.textColorSecondary));
    } else {
      text = TextSpan(
          style: TextStyle(color: theme.textColorSecondary, fontSize: 12),
          children: _createKeysSpans(_entries.toList(),
              style: TextStyle(
                  color: theme.textColorPrimary, fontWeight: FontWeight.w600),
              delimiter: ' + '));
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.dividerColor, width: 0.5)),
      child: Row(
        children: [
          Expanded(
              child: RichText(
            text: text,
            textAlign: TextAlign.center,
          )),
          SizedBox(
            height: 16,
            width: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.green,
              value: _controller?.value,
            ),
          )
        ],
      ),
    );
  }

  final _entries = <InputEntry>{};

  void _handleKeyboardEvent(
      {required int keyCode, required String keyLabel, required bool down}) {
    debugPrint('Keyboard $keyCode $keyLabel $down');

    final entry = InputEntry(code: keyCode, type: 0, name: keyLabel);
    if (down) {
      _entries.add(entry);
    }

    setState(() {});
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      widget.onCompleted?.call(_entries);
    }
  }

  void _handleAnimationProgress() {
    setState(() {});
  }
}

class _LoggerListenerPair {
  final HidListenerBackend backend;
  final int? listenerId;

  _LoggerListenerPair({required this.backend, required this.listenerId});

  void dispose() {
    final listenerId = this.listenerId;
    if (listenerId != null) {
      backend.removeKeyboardListener(listenerId);
    }
  }
}
