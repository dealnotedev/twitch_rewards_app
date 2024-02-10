import 'package:flutter/material.dart';
import 'package:twitch_listener/delay_widget.dart';
import 'package:twitch_listener/enable_input_widget.dart';
import 'package:twitch_listener/reward.dart';
import 'package:twitch_listener/themes.dart';

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
    AddAction(title: 'Delay', type: RewardAction.typeDelay)
  ];

  late final TextEditingController _nameController;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 8),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
          color: const Color(0xFF363A46),
          borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: [
          TextField(
            maxLines: 1,
            controller: _nameController,
            style: const TextStyle(
              fontSize: 14,
            ),
            decoration: const DefaultInputDecoration(hintText: 'Reward name'),
          ),
          const SizedBox(
            height: 8,
          ),
          ..._reward.handlers.map((e) => Container(
                width: double.infinity,
                margin: const EdgeInsets.only(left: 48, top: 8, bottom: 8),
                padding: const EdgeInsets.only(
                    left: 16, right: 8, top: 8, bottom: 8),
                decoration: BoxDecoration(
                    border: Border.all(
                        color: Colors.white.withOpacity(0.1), width: 1),
                    borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    Expanded(child: _createActionWidget(context, action: e)),
                    IconButton(onPressed: () => _handleActionDelete(e), icon: const Icon(Icons.delete))
                  ],
                ),
              )),
          const SizedBox(
            height: 8,
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableActions
                .map((e) => ElevatedButton(
                    onPressed: () => _handleAddAction(e), child: Text(e.title)))
                .toList(),
          )
        ],
      ),
    );
  }

  Widget _createActionWidget(BuildContext context,
      {required RewardAction action}) {
    switch (action.type) {
      case RewardAction.typeEnableInput:
        return EnableInputWidget(action: action, saveHook: widget.saveHook);

      case RewardAction.typeDelay:
        return DelayWidget(saveHook: widget.saveHook, action: action);
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
