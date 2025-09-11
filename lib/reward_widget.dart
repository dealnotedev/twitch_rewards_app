import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:twitch_listener/audioplayer.dart';
import 'package:twitch_listener/reward.dart';
import 'package:twitch_listener/rewards/crash_process_widget.dart';
import 'package:twitch_listener/rewards/delay_widget.dart';
import 'package:twitch_listener/rewards/enable_filter_widget.dart';
import 'package:twitch_listener/rewards/enable_input_widget.dart';
import 'package:twitch_listener/rewards/enable_source_widget.dart';
import 'package:twitch_listener/rewards/flip_source_widget.dart';
import 'package:twitch_listener/rewards/invert_filter_widget.dart';
import 'package:twitch_listener/rewards/play_audio_widget.dart';
import 'package:twitch_listener/rewards/play_audios_widget.dart';
import 'package:twitch_listener/rewards/send_input_widget.dart';
import 'package:twitch_listener/rewards/set_scene_widget.dart';
import 'package:twitch_listener/rewards/toggle_source_widget.dart';
import 'package:twitch_listener/themes.dart';

class RewardWidget extends StatefulWidget {
  final void Function(Reward reward) onDelete;
  final void Function(Reward reward) onPlay;

  final SaveHook saveHook;
  final Reward reward;
  final Audioplayer audioplayer;

  const RewardWidget(
      {super.key,
      required this.reward,
      required this.saveHook,
      required this.onDelete,
      required this.onPlay,
      required this.audioplayer});

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
    AddAction(
        title: 'Enable input',
        type: RewardAction.typeEnableInput,
        icon: Icons.mic_outlined),
    AddAction(
        title: 'Delay',
        type: RewardAction.typeDelay,
        icon: Icons.timer_outlined),
    AddAction(
        title: 'Play audio (legacy)',
        type: RewardAction.typePlayAudio,
        icon: Icons.audiotrack_outlined),
    AddAction(
        title: 'Play audio',
        type: RewardAction.typePlayAudios,
        icon: Icons.audiotrack_outlined),
    AddAction(
        title: 'Enable filter',
        type: RewardAction.typeEnableFilter,
        icon: Icons.photo_filter_outlined),
    AddAction(
        title: 'Invert filter',
        type: RewardAction.typeInvertFilter,
        icon: Icons.photo_filter_outlined),
    AddAction(
        title: 'Flip source',
        type: RewardAction.typeFlipSource,
        icon: Icons.flip_outlined),
    AddAction(
        title: 'Enable source',
        type: RewardAction.typeEnableSource,
        icon: Icons.check_box_outlined),
    AddAction(
        title: 'Toggle source',
        type: RewardAction.typeToggleSource,
        icon: Icons.check_box_outlined),
    AddAction(
        title: 'Set scene',
        type: RewardAction.typeSetScene,
        icon: Icons.forward_outlined),
    AddAction(
        title: 'Crash process',
        type: RewardAction.typeCrashProcess,
        icon: Icons.error_outline),
    AddAction(
        title: 'Send input',
        type: RewardAction.typeSendInput,
        icon: Icons.keyboard_alt_outlined)
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
            PopupMenuButton(
              tooltip: '',
              elevation: 1,
              onSelected: _handleAddAction,
              itemBuilder: (context) {
                return _availableActions
                    .map((a) => PopupMenuItem(
                          padding: EdgeInsets.zero,
                          value: a,
                          height: 32,
                          child: Row(
                            children: [
                              const Gap(12),
                              Icon(
                                a.icon,
                                size: 20,
                              ),
                              const Gap(12),
                              Expanded(child: Text(a.title)),
                              const Gap(12)
                            ],
                          ),
                        ))
                    .toList();
              },
              icon: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.add,
                    size: 20,
                  ),
                  Gap(4),
                  Text('Add action')
                ],
              ),
            ),
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
            audioplayer: widget.audioplayer,
            saveHook: widget.saveHook,
            action: action,
            key: Key(action.id));

      case RewardAction.typePlayAudios:
        return PlayAudiosWidget(
            audioplayer: widget.audioplayer,
            saveHook: widget.saveHook,
            action: action,
            key: Key(action.id));

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
      _reward.handlers.add(RewardAction.create(e.type));
    });
  }

  void _handleActionDelete(RewardAction e) {
    e.dispose();

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
    return [
      ReorderableList(
          shrinkWrap: true,
          proxyDecorator: (child, index, _) {
            return Material(
              color: const Color(0xFF424654),
              elevation: 8,
              borderRadius: BorderRadius.circular(4),
              child: child,
            );
          },
          itemBuilder: (context, index) {
            final e = handlers[index];
            return Material(
              type: MaterialType.transparency,
              key: Key(e.id),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                child: Row(
                  crossAxisAlignment: ([
                    RewardAction.typeSetScene,
                    RewardAction.typePlayAudios
                  ].contains(e.type))
                      ? CrossAxisAlignment.start
                      : CrossAxisAlignment.center,
                  children: [
                    ReorderableDragStartListener(
                      index: index,
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(
                          Icons.list,
                          color: Color(0xFFCBC4CF),
                        ),
                      ),
                    ),
                    const Gap(12),
                    Expanded(child: _createActionWidget(context, action: e)),
                    const Gap(4),
                    IconButton(
                        onPressed: () => _handleActionDelete(e),
                        icon: const Icon(Icons.delete))
                  ],
                ),
              ),
            );
          },
          itemCount: handlers.length,
          onReorder: (oldIndex, newIndex) {
            setState(() {
              if (oldIndex < newIndex) {
                newIndex -= 1;
              }
              final item = handlers.removeAt(oldIndex);
              handlers.insert(newIndex, item);
            });
          })
    ];
  }
}

class AddAction {
  final String title;
  final String type;
  final IconData icon;

  AddAction({required this.title, required this.type, required this.icon});
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
