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
    return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(
              'Send input',
              style: TextStyle(color: Colors.white),
            ),
            Gap(16),
            Expanded(
              child: _KeylogWidget(),
            ),
          ])
        ]);
  }

  @override
  void didUpdateWidget(covariant SendInputWidget oldWidget) {
    if (widget.saveHook != oldWidget.saveHook) {
      oldWidget.saveHook.removeHandler(_handleSave);
      widget.saveHook.addHandler(_handleSave);
    }
    super.didUpdateWidget(oldWidget);
  }

  void _handleSave() {}
}

class _KeylogWidget extends StatefulWidget {
  final VoidCallback? onCompleted;

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
    return Container(
      decoration: const BoxDecoration(
          color: Color(0xFF272E37),
          borderRadius: BorderRadius.only(topLeft: radius, topRight: radius)),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              _entries.map((e) => e.name).join("+"),
              style: const TextStyle(color: Colors.white),
            ),
          ),
          LinearProgressIndicator(
            minHeight: 2,
            color: Colors.green,
            value: _controller?.value,
          ),
        ],
      ),
    );
  }

  final _entries = <InputEntry>{};
  final _current = <InputEntry>{};

  void _handleKeyboardEvent(
      {required int keyCode, required String keyLabel, required bool down}) {
    debugPrint('Keyboard $keyCode $keyLabel $down');

    if (_current.isEmpty && down) {
      _entries.clear();
    }

    final entry = InputEntry(code: keyCode, type: 0, name: keyLabel);
    if (down) {
      _entries.add(entry);
      _current.add(entry);
    } else {
      _current.remove(entry);
    }

    setState(() {});
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      widget.onCompleted?.call();
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
