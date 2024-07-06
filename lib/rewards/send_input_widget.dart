import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:hid_listener/hid_listener.dart';
import 'package:twitch_listener/reward.dart';
import 'package:twitch_listener/reward_widget.dart';
import 'package:twitch_listener/rewards/keys_logger.dart';

class SendInputWidget extends StatefulWidget {
  final SaveHook saveHook;
  final RewardAction action;

  const SendInputWidget(
      {super.key, required this.saveHook, required this.action});

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<SendInputWidget> {
  @override
  void initState() {
    _entries = widget.action.inputs;
    widget.saveHook.addHandler(_handleSave);
    super.initState();
  }

  @override
  void dispose() {
    widget.saveHook.removeHandler(_handleSave);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Text(
          'Send input',
          style: TextStyle(color: Colors.white),
        ),
        const Gap(16),
        Expanded(
          child: _recording
              ? _KeylogWidget(onCompleted: _handleEntriesRecorded)
              : _createConbinationState(),
        ),
        const Gap(8),
        ElevatedButton(
            onPressed: _recording ? null : () => _handleSetupClick(context),
            child: const Text('Setup'))
      ])
    ]);
  }

  Widget _createConbinationState() {
    const radius = Radius.circular(4);

    final TextSpan text;
    if (_entries.isEmpty) {
      text = const TextSpan(
          text: 'Click "Setup" to configure',
          style:
              TextStyle(color: Color(0xFFA9ABAF), fontWeight: FontWeight.w600));
    } else {
      text = TextSpan(
          style: const TextStyle(color: Colors.white),
          children: _createKeysSpans(_entries,
              style: const TextStyle(
                  color: Colors.green, fontWeight: FontWeight.w600),
              delimiter: ' + '));
    }

    return Container(
      decoration: const BoxDecoration(
          color: Color(0xFF272E37),
          borderRadius: BorderRadius.only(topLeft: radius, topRight: radius)),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: RichText(text: text),
          ),
          const Divider(color: Color(0xFFCBC4CF), height: 1, thickness: 1)
        ],
      ),
    );
  }

  List<InputEntry> _entries = [];
  bool _recording = false;

  @override
  void didUpdateWidget(covariant SendInputWidget oldWidget) {
    if (widget.saveHook != oldWidget.saveHook) {
      oldWidget.saveHook.removeHandler(_handleSave);
      widget.saveHook.addHandler(_handleSave);
    }
    super.didUpdateWidget(oldWidget);
  }

  void _handleSave() {
    widget.action.inputs = _entries;
  }

  void _handleSetupClick(BuildContext context) {
    setState(() {
      _recording = true;
    });
  }

  void _handleEntriesRecorded(Set<InputEntry> entries) {
    setState(() {
      _recording = false;
      _entries = List.of(entries);
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
    const radius = Radius.circular(4);

    final TextSpan text;
    if (_entries.isEmpty) {
      text = const TextSpan(
          text: 'Press the combination...',
          style:
              TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFA9ABAF)));
    } else {
      text = TextSpan(
          style: const TextStyle(color: Colors.white),
          children: _createKeysSpans(_entries.toList(),
              style: const TextStyle(
                  color: Colors.green, fontWeight: FontWeight.w600),
              delimiter: ' + '));
    }

    return Container(
      decoration: const BoxDecoration(
          color: Color(0xFF272E37),
          borderRadius: BorderRadius.only(topLeft: radius, topRight: radius)),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: RichText(
              text: text,
            ),
          ),
          LinearProgressIndicator(
            minHeight: 1,
            color: Colors.green,
            value: _controller?.value,
          ),
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
