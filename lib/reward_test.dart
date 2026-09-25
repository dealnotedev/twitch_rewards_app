import 'package:flutter/material.dart';

import 'extensions.dart';
import 'music/music_requests.dart';
import 'reward.dart';
import 'reward_executor.dart';

/// Manual tests need the same viewer input that a real redemption carries.
Future<void> testReward(
    BuildContext context, Reward reward, RewardExecutor executor) async {
  String? input;
  if (reward.handlers
      .any((a) => !a.disabled && a.type == RewardAction.typeQueueTrack)) {
    input = await showDialog<String>(
        context: context, builder: (_) => const _TrackInputDialog());
    if (input == null || !context.mounted) return;
  }
  await executor.execute(reward, userInput: input);
}

class _TrackInputDialog extends StatefulWidget {
  const _TrackInputDialog();

  @override
  State<_TrackInputDialog> createState() => _TrackInputDialogState();
}

class _TrackInputDialogState extends State<_TrackInputDialog> {
  final _controller = TextEditingController();
  bool _invalid = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (MusicRequestManager.parseYoutubeUrl(_controller.text) == null) {
      setState(() => _invalid = true);
      return;
    }
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final l = context.localizations;
    return AlertDialog(
      title: Text(l.music_test_title),
      content: SizedBox(
          width: 400,
          child: TextField(
              controller: _controller,
              autofocus: true,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                  labelText: l.music_youtube_url,
                  hintText: 'https://www.youtube.com/watch?v=...',
                  errorText: _invalid ? l.music_invalid_url : null))),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel)),
        TextButton(onPressed: _submit, child: Text(l.music_test_run)),
      ],
    );
  }
}
