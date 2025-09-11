import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:twitch_listener/actions/volume_slider.dart';
import 'package:twitch_listener/audioplayer.dart';
import 'package:twitch_listener/buttons.dart';
import 'package:twitch_listener/extensions.dart';
import 'package:twitch_listener/generated/assets.dart';
import 'package:twitch_listener/reward.dart';
import 'package:twitch_listener/simple_icon.dart';
import 'package:twitch_listener/text_field_decoration.dart';
import 'package:twitch_listener/themes.dart';

class PlayAudioWidget extends StatefulWidget {
  final RewardAction action;
  final Audioplayer audioplayer;

  const PlayAudioWidget(
      {super.key, required this.action, required this.audioplayer});

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<PlayAudioWidget> {
  late final RewardAction _action;
  late final Audioplayer _audioplayer;

  late final TextEditingController _controller;

  final _focusNode = FocusNode();

  @override
  void initState() {
    _action = widget.action;
    _audioplayer = widget.audioplayer;
    _controller = TextEditingController(text: _action.filePath);
    _controller.addListener(_handlePathEdit);
    super.initState();
  }

  @override
  void dispose() {
    _controller.removeListener(_handlePathEdit);
    _controller.dispose();
    _focusNode.dispose();
    _stopVolumePlaying();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            SimpleIcon.simpleSquare(Assets.assetsIcMusicNoteWhite16dp,
                size: 16, color: theme.textColorPrimary),
            const Gap(16),
            Expanded(
                child: TextFieldDecoration(
                    clearable: false,
                    builder: (cntx, decoration, style) {
                      return TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        textInputAction: TextInputAction.search,
                        style: style,
                        decoration: decoration,
                      );
                    },
                    hint: context.localizations.reaction_play_audio_path_hint,
                    controller: _controller,
                    focusNode: _focusNode,
                    theme: theme)),
            const Gap(16),
            VolumeSlider(
                theme: theme,
                volume: _action.volume,
                onChangeChange: _onVolumeChange,
                onChangeEnd: _onVolumeEnd,
                onChangeStart: _onVolumeStart),
            const Gap(16),
            CustomButton(
              text: context.localizations.button_select_file,
              style: CustomButtonStyle.secondary,
              theme: theme,
              onTap: () => _selectFile(context),
            )
          ],
        )
      ],
    );
  }

  PlayToken? _playToken;

  void _onVolumeEnd(double value) {
    _stopVolumePlaying();
  }

  void _stopVolumePlaying() {
    final playToken = _playToken;
    _playToken = null;

    if (playToken != null) {
      _audioplayer.cancelByToken(playToken);
    }
  }

  void _onVolumeStart(double value) async {
    _stopVolumePlaying();

    final file = File(_controller.text.trim());

    if (file.existsSync()) {
      _playToken = await _audioplayer.playFileInfinitely(file.path,
          volume: widget.action.volume);
    }
  }

  void _selectFile(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
        dialogTitle:
            context.localizations.reaction_play_audio_select_file_dialog,
        type: FileType.custom,
        allowedExtensions: ['wav', 'mp3', 'ogg'],
        allowMultiple: false);

    final path = result?.files.firstOrNull?.path;

    if (path != null) {
      _controller.text = path;
    }
  }

  void _onVolumeChange(double v) {
    setState(() {
      _action.volume.set(v);
    });
  }

  void _handlePathEdit() {
    _action.filePath = _controller.text.trim();
  }
}
