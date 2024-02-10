import 'package:flutter/material.dart';
import 'package:twitch_listener/reward.dart';

class RewardWidget extends StatefulWidget {
  final SaveHook saveHook;
  final Reward reward;

  const RewardWidget({super.key, required this.reward, required this.saveHook});

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<RewardWidget> {
  late final Reward _reward;

  @override
  void initState() {
    _reward = widget.reward;
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
          color: const Color(0xFF363A46),
          borderRadius: BorderRadius.circular(8)),
      child: Text(
        _reward.name,
        style: const TextStyle(color: Colors.white),
      ),
    );
  }

  @override
  void didUpdateWidget(covariant RewardWidget oldWidget) {
    if (widget.saveHook != oldWidget.saveHook) {
      oldWidget.saveHook.removeHandler(_handleSave);
      widget.saveHook.addHandler(_handleSave);
    }
    super.didUpdateWidget(oldWidget);
  }

  void _handleSave() {

  }
}

class SaveHook {
  final _handlers = <VoidCallback>{};

  void addHandler(VoidCallback callback) {
    _handlers.add(callback);
  }

  void removeHandler(VoidCallback callback) {
    _handlers.remove(callback);
  }

  void stop() {
    for (var callback in _handlers) {
      callback.call();
    }
  }
}
