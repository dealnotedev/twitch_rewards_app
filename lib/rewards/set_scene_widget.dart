import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:twitch_listener/reward.dart';
import 'package:twitch_listener/reward_widget.dart';
import 'package:twitch_listener/themes.dart';

class SetSceneWidget extends StatefulWidget {
  final SaveHook saveHook;
  final RewardAction action;

  const SetSceneWidget(
      {super.key, required this.saveHook, required this.action});

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<SetSceneWidget> {
  final _targets = <_Target>[];

  @override
  void initState() {
    final legacyTarget = widget.action.sceneName;

    if (legacyTarget != null && legacyTarget.isNotEmpty) {
      _targets.add(_Target(id: legacyTarget));
    } else {
      _targets.addAll(widget.action.targets.map((e) => _Target(id: e)));
    }

    _sceneNameController = TextEditingController(text: '');
    widget.saveHook.addHandler(_handleSave);
    super.initState();
  }

  @override
  void dispose() {
    _sceneNameController.dispose();
    widget.saveHook.removeHandler(_handleSave);
    super.dispose();
  }

  late final TextEditingController _sceneNameController;

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Text(
          'Set scene',
          style: TextStyle(color: Colors.white),
        ),
      ),
      const Gap(16),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              maxLines: 1,
              controller: _sceneNameController,
              onFieldSubmitted: _handleSceneNameSubmitted,
              style: const TextStyle(
                fontSize: 14,
              ),
              decoration: const DefaultInputDecoration(
                  hintText: 'Type and press "Enter"'),
            ),
            if (_targets.isNotEmpty) ...[
              const Gap(8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: _targets.map(_createTargetWidget).toList(),
              )
            ]
          ],
        ),
      )
    ]);
  }

  @override
  void didUpdateWidget(covariant SetSceneWidget oldWidget) {
    if (widget.saveHook != oldWidget.saveHook) {
      oldWidget.saveHook.removeHandler(_handleSave);
      widget.saveHook.addHandler(_handleSave);
    }
    super.didUpdateWidget(oldWidget);
  }

  void _handleSave() {
    widget.action.sceneName = null;
    widget.action.targets = _targets.map((e) => e.id).toList();
  }

  void _handleSceneNameSubmitted(String name) {
    if (name.isNotEmpty) {
      final target = _Target(id: name);

      if (_targets.contains(target)) {
        return;
      }

      setState(() {
        _sceneNameController.text = '';
        _targets.add(target);
      });
    }
  }

  Widget _createTargetWidget(_Target target) {
    return Container(
      padding: const EdgeInsets.only(top: 4, bottom: 4, left: 12, right: 4),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: const Color(0xFF272E37)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            target.id,
            style: const TextStyle(
                height: 1.25,
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.w500),
          ),
          const Gap(4),
          IconButton(
              iconSize: 16,
              padding: const EdgeInsets.all(2),
              constraints: const BoxConstraints(minHeight: 0, minWidth: 0),
              onPressed: () => _handleTargetDeleteClick(target),
              icon: const Icon(Icons.close))
        ],
      ),
    );
  }

  void _handleTargetDeleteClick(_Target target) {
    setState(() {
      _targets.remove(target);
    });
  }
}

class _Target {
  final String id;

  _Target({required this.id});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _Target && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
