import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:twitch_listener/reward.dart';
import 'package:twitch_listener/rewards/crash_process_widget.dart';
import 'package:twitch_listener/rewards/delay_widget.dart';
import 'package:twitch_listener/rewards/enable_filter_widget.dart';
import 'package:twitch_listener/rewards/enable_input_widget.dart';
import 'package:twitch_listener/rewards/enable_source_widget.dart';
import 'package:twitch_listener/rewards/flip_source_widget.dart';
import 'package:twitch_listener/rewards/invert_filter_widget.dart';
import 'package:twitch_listener/rewards/play_audio_widget.dart';
import 'package:twitch_listener/rewards/send_input_widget.dart';
import 'package:twitch_listener/rewards/set_scene_widget.dart';
import 'package:twitch_listener/rewards/toggle_source_widget.dart';
import 'package:twitch_listener/themes.dart';

class RewardWidget extends StatefulWidget {
  final void Function(Reward reward) onDelete;
  final void Function(Reward reward) onPlay;

  final SaveHook saveHook;
  final Reward reward;

  const RewardWidget(
      {super.key,
      required this.reward,
      required this.saveHook,
      required this.onDelete,
      required this.onPlay});

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<RewardWidget> {
  late final Reward _reward;

  @override
  void initState() {
    _reward = widget.reward;
    _nameController = TextEditingController(text: _reward.name);
    widget.saveHook.addHandler(_handleSave);
    super.initState();
  }

  @override
  void dispose() {
    _nameController.dispose();
    widget.saveHook.removeHandler(_handleSave);
    super.dispose();
  }

  final _availableActions = <AddAction>[
    AddAction(title: 'Enable input', type: RewardAction.typeEnableInput),
    AddAction(title: 'Delay', type: RewardAction.typeDelay),
    AddAction(title: 'Play audio', type: RewardAction.typePlayAudio),
    AddAction(title: 'Enable filter', type: RewardAction.typeEnableFilter),
    AddAction(title: 'Invert filter', type: RewardAction.typeInvertFilter),
    AddAction(title: 'Flip source', type: RewardAction.typeFlipSource),
    AddAction(title: 'Enable source', type: RewardAction.typeEnableSource),
    AddAction(title: 'Toggle source', type: RewardAction.typeToggleSource),
    AddAction(title: 'Set scene', type: RewardAction.typeSetScene),
    AddAction(title: 'Crash process', type: RewardAction.typeCrashProcess),
    AddAction(title: 'Send input', type: RewardAction.typeSendInput)
  ];

  late final TextEditingController _nameController;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(left: 16, right: 8, top: 16, bottom: 8),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
          color: const Color(0xFF363A46),
          borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                  child: TextField(
                maxLines: 1,
                controller: _nameController,
                style: const TextStyle(
                  fontSize: 14,
                ),
                decoration:
                    const DefaultInputDecoration(hintText: 'Reward name'),
              )),
              const Gap(8),
              IconButton(
                  onPressed: _handleExpandClick,
                  icon: Icon(_reward.expanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down)),
              IconButton(
                  onPressed: _handlePlayClick,
                  icon: const Icon(Icons.play_arrow)),
              IconButton(
                  onPressed: _handleDeleteClick, icon: const Icon(Icons.delete))
            ],
          ),
          if (_reward.expanded) ...[
            const Gap(8),
            ..._createRewarActionsWidget(context, _reward.handlers),
            const Gap(8),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: _availableActions
                    .map((e) => ElevatedButton(
                        onPressed: () => _handleAddAction(e),
                        style: ButtonStyle(
                            padding: WidgetStateProperty.all(
                                const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8))),
                        child: Text(
                          e.title,
                          style: const TextStyle(fontSize: 13),
                        )))
                    .toList(),
              ),
            ),
            const Gap(8),
          ] else ...[
            const Gap(8),
          ]
        ],
      ),
    );
  }

  Widget _createActionWidget(BuildContext context,
      {required RewardAction action}) {
    switch (action.type) {
      case RewardAction.typeEnableInput:
        return EnableInputWidget(
            action: action, saveHook: widget.saveHook, key: Key(action.id));

      case RewardAction.typeDelay:
        return DelayWidget(
            saveHook: widget.saveHook, action: action, key: Key(action.id));

      case RewardAction.typePlayAudio:
        return PlayAudioWidget(
            saveHook: widget.saveHook, action: action, key: Key(action.id));

      case RewardAction.typeEnableFilter:
        return EnableFilterWidget(
            saveHook: widget.saveHook, action: action, key: Key(action.id));

      case RewardAction.typeInvertFilter:
        return InvertFilterWidget(
            saveHook: widget.saveHook, action: action, key: Key(action.id));

      case RewardAction.typeFlipSource:
        return FlipSceneWidget(
            saveHook: widget.saveHook, action: action, key: Key(action.id));

      case RewardAction.typeEnableSource:
        return EnableSourceWidget(
            saveHook: widget.saveHook, action: action, key: Key(action.id));

      case RewardAction.typeToggleSource:
        return ToggleSourceWidget(
            saveHook: widget.saveHook, action: action, key: Key(action.id));

      case RewardAction.typeSetScene:
        return SetSceneWidget(
            saveHook: widget.saveHook, action: action, key: Key(action.id));

      case RewardAction.typeCrashProcess:
        return CrashProcessWidget(
            saveHook: widget.saveHook, action: action, key: Key(action.id));

      case RewardAction.typeSendInput:
        return SendInputWidget(
            saveHook: widget.saveHook, action: action, key: Key(action.id));
    }

    throw StateError('Unsupported action ${action.type}');
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
    _reward.name = _nameController.text;
  }

  void _handleAddAction(AddAction e) {
    setState(() {
      _reward.handlers.add(RewardAction(type: e.type));
    });
  }

  _handleActionDelete(RewardAction e) {
    setState(() {
      _reward.handlers.remove(e);
    });
  }

  void _handleExpandClick() {
    setState(() {
      _reward.expanded = !_reward.expanded;
    });
  }

  void _handleDeleteClick() {
    widget.onDelete.call(_reward);
  }

  void _handlePlayClick() {
    widget.onPlay.call(_reward);
  }

  List<Widget> _createRewarActionsWidget(
      BuildContext context, List<RewardAction> handlers) {
    return handlers.mapIndexed((index, e) {
      final canUp = index > 0;
      final canDown = index < handlers.length - 1;
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: Row(
          crossAxisAlignment: e.type == RewardAction.typeSetScene
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          children: [
            _ReorderWidget(
              onDown:
                  canDown ? () => _moveItem(handlers, index, up: false) : null,
              onUp: canUp ? () => _moveItem(handlers, index, up: true) : null,
            ),
            const Gap(16),
            Expanded(child: _createActionWidget(context, action: e)),
            IconButton(
                onPressed: () => _handleActionDelete(e),
                icon: const Icon(Icons.delete))
          ],
        ),
      );
    }).toList();
  }

  void _moveItem(List<RewardAction> actions, int from, {required bool up}) {
    setState(() {
      final h = actions.removeAt(from);
      actions.insert(from + (up ? -1 : 1), h);
    });
  }
}

class AddAction {
  final String title;
  final String type;

  AddAction({required this.title, required this.type});
}

class SaveHook {
  final _handlers = <VoidCallback>{};

  void addHandler(VoidCallback callback) {
    _handlers.add(callback);
  }

  void removeHandler(VoidCallback callback) {
    _handlers.remove(callback);
  }

  void save() {
    for (var callback in _handlers) {
      callback.call();
    }
  }
}

class _ReorderWidget extends StatefulWidget {
  final VoidCallback? onUp;
  final VoidCallback? onDown;

  const _ReorderWidget({this.onUp, this.onDown});

  @override
  State<StatefulWidget> createState() => _ReorderWidgetState();
}

class _ReorderWidgetState extends State<_ReorderWidget> {
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _handleMouseEnter(true),
      onExit: (_) => _handleMouseEnter(false),
      child: Visibility(
        visible: _entered,
        maintainState: true,
        maintainSize: true,
        maintainAnimation: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                  iconSize: 16,
                  padding: const EdgeInsets.all(2),
                  constraints: const BoxConstraints(minHeight: 0, minWidth: 0),
                  onPressed: widget.onUp,
                  icon: const Icon(Icons.arrow_upward)),
              IconButton(
                  iconSize: 16,
                  padding: const EdgeInsets.all(2),
                  constraints: const BoxConstraints(minHeight: 0, minWidth: 0),
                  onPressed: widget.onDown,
                  icon: const Icon(Icons.arrow_downward))
            ],
          ),
        ),
      ),
    );
  }

  bool _entered = false;

  void _handleMouseEnter(bool entered) {
    setState(() {
      _entered = entered;
    });
  }
}
