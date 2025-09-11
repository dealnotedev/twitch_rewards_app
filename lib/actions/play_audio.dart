import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
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
            SizedBox(
                width: 84,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    _createSlider(context, theme),
                    _createSliderValues(context, theme)
                  ],
                )),
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

  Widget _createSliderValues(BuildContext context, ThemeData theme) {
    final volume = _action.volume.current;
    final volumePercentage = '${(volume * 100.0).round()}%';

    const style =
        TextStyle(fontSize: 10, fontWeight: FontWeight.w500, height: 1);
    return IgnorePointer(
      child: Row(
        children: [
          Expanded(
              child: Visibility(
                  visible: volume > 1.5,
                  child: Text(
                    volumePercentage,
                    textAlign: TextAlign.center,
                    style:
                        style.copyWith(color: theme.textColorPrimaryInverted),
                  ))),
          Expanded(
              child: Visibility(
                  visible: volume <= 1.5,
                  child: Text(
                    volumePercentage,
                    textAlign: TextAlign.center,
                    style: style.copyWith(color: theme.textColorPrimary),
                  )))
        ],
      ),
    );
  }

  Widget _createSlider(BuildContext context, ThemeData theme) {
    final Color thumbColor;

    final Color activeColor;
    final Color inactiveColor;

    if (theme.dark) {
      activeColor = const Color(0xFFEEEEEE);
      inactiveColor = const Color(0xFF252525);
      thumbColor = const Color(0xFF121212);
    } else {
      activeColor = const Color(0xFF030213);
      inactiveColor = const Color(0xFFCBCED4);
      thumbColor = Colors.white;
    }

    return SliderTheme(
        data: SliderTheme.of(context).copyWith(
            inactiveTrackColor: inactiveColor,
            trackHeight: 14,
            overlayColor: Colors.transparent,
            padding: EdgeInsets.zero,
            activeTrackColor: activeColor,
            thumbColor: thumbColor,
            thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 6,
                elevation: 0,
                pressedElevation: 0,
                disabledThumbRadius: 6)),
        child: Slider(
            max: 3.0,
            divisions: 60,
            value: _action.volume.current,
            onChangeStart: (v) => _onVolumeStart(v),
            onChangeEnd: (v) => _onVolumeEnd(v),
            onChanged: (v) => _onVolumeChange(v)));
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
        allowedExtensions: ['wav', 'mp3'],
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
