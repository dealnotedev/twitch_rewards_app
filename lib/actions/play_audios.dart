import 'dart:io';

import 'package:collection/collection.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:twitch_listener/actions/volume_slider.dart';
import 'package:twitch_listener/audioplayer.dart';
import 'package:twitch_listener/buttons.dart';
import 'package:twitch_listener/dropdown/dropdown_menu.dart';
import 'package:twitch_listener/dropdown/simple_dropdown.dart';
import 'package:twitch_listener/extensions.dart';
import 'package:twitch_listener/generated/assets.dart';
import 'package:twitch_listener/reward.dart';
import 'package:twitch_listener/ripple_icon.dart';
import 'package:twitch_listener/simple_icon.dart';
import 'package:twitch_listener/themes.dart';

class PlayAudiosWidget extends StatefulWidget {
  final RewardAction action;
  final Audioplayer audioplayer;
  final VoidCallback changesCallback;

  const PlayAudiosWidget({super.key,
    required this.action,
    required this.audioplayer,
    required this.changesCallback});

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<PlayAudiosWidget> {
  late final RewardAction _action;
  late final Audioplayer _audioplayer;

  @override
  void initState() {
    _action = widget.action;
    _audioplayer = widget.audioplayer;
    super.initState();
  }

  @override
  void dispose() {
    _stopVolumePlaying();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final files = _action.audios;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
                child: Text(
              context.localizations.reaction_play_audios_audio_files_title,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: theme.textColorPrimary),
            )),
            const Gap(12),
            CustomButton(
              prefixIcon: Assets.assetsIcPlusWhite16dp,
              text: context.localizations.reaction_play_audios_button_add_file,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              style: CustomButtonStyle.secondary,
              theme: theme,
              onTap: () => _selectFile(context),
            )
          ],
        ),
        const Gap(8),
        if (files.isEmpty) ...[
          const Gap(16),
          SizedBox(
            width: double.infinity,
            child: Text(
              context.localizations.reaction_play_audios_no_files,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: theme.textColorSecondary),
            ),
          ),
          const Gap(8)
        ] else ...[
          Container(
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.dividerColor, width: 0.5)),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(
              spacing: 4,
              children: files
                  .mapIndexed((index, f) => _createAudioFileWidget(
                      context, theme,
                      entry: f, index: index))
                  .toList(),
            ),
          ),
          const Gap(16),
          Row(
            spacing: 8,
            children: [
              Expanded(child: _createWaitCompletion(context, theme)),
              Expanded(child: _createShuffle(context, theme)),
              Expanded(child: _createNumberOfTracks(context, theme))
            ],
          )
        ]
      ],
    );
  }

  final _waitCompletionKey = GlobalKey();
  final _shuffleKey = GlobalKey();
  final _countKey = GlobalKey();

  Widget _createWaitCompletion(BuildContext context, ThemeData theme) {
    return SimpleDropdown<bool>(
        theme: theme,
        title: context.localizations.reaction_play_audios_wait_for_completion,
        available: [
          Item(id: true, title: context.localizations.yes),
          Item(id: false, title: context.localizations.no)
        ],
        globalKey: _waitCompletionKey,
        selected: _action.awaitCompletion,
        onSelected: _handleAwaitCompletion);
  }

  void _handleAwaitCompletion(bool value) {
    setState(() {
      _action.awaitCompletion = value;
      widget.changesCallback();
    });
  }

  Widget _createNumberOfTracks(BuildContext context, ThemeData theme) {
    final items = <Item<int>>[];
    items.add(Item(
        id: -1, title: context.localizations.reaction_play_audios_count_all));

    final selected = _action.count ?? -1;

    bool hasSelection = selected == -1;

    for (int i = 0; i < _action.audios.length; i++) {
      final count = i + 1;
      items.add(Item(id: count, title: count.toString()));
      hasSelection = hasSelection || count == selected;
    }

    if (!hasSelection) {
      items.add(Item(id: selected, title: selected.toString()));
    }

    return SimpleDropdown<int>(
        theme: theme,
        title: context.localizations.reaction_play_audios_count_title,
        available: items,
        globalKey: _countKey,
        selected: _action.count ?? -1,
        onSelected: _handleCountEdited);
  }

  Widget _createShuffle(BuildContext context, ThemeData theme) {
    return SimpleDropdown<bool>(
        theme: theme,
        title: context.localizations.reaction_play_audios_shuffle,
        available: [
          Item(id: true, title: context.localizations.yes),
          Item(id: false, title: context.localizations.no)
        ],
        globalKey: _shuffleKey,
        selected: _action.randomize,
        onSelected: (value) {
          setState(() {
            _action.randomize = value;
          });
        });
  }

  Widget _createAudioFileWidget(BuildContext context, ThemeData theme,
      {required AudioEntry entry, required int index}) {
    return Row(
      children: [
        const Gap(6),
        SimpleIcon.simpleSquare(Assets.assetsIcMusicNoteWhite16dp,
            size: 16, color: theme.textColorPrimary),
        const Gap(4),
        Text(
          (index + 1).toString(),
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: theme.textColorPrimary),
        ),
        const Gap(12),
        Expanded(
            child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: theme.inputBackground,
          ),
          child: Text(
            entry.path,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: theme.textColorPrimary,
              height: 1,
            ),
          ),
        )),
        const Gap(8),
        VolumeSlider(
          theme: theme,
          volume: entry.volume,
          onChangeEnd: (v) => _onVolumeEnd(entry, v),
          onChangeChange: (v) => _onVolumeChange(entry, v),
          onChangeStart: (v) => _onVolumeStart(entry, v),
        ),
        const Gap(8),
        RippleIcon(
            borderRadius: BorderRadius.circular(8),
            icon: Assets.assetsIcDeleteWhite16dp,
            onTap: () {
              _handleDeleteClick(entry);
            },
            size: 16,
            color: theme.textColorPrimary),
      ],
    );
  }

  PlayToken? _playToken;

  void _onVolumeEnd(AudioEntry entry, double value) {
    _stopVolumePlaying();

    setState(() {
      entry.volume.set(value);
      widget.changesCallback();
    });
  }

  void _stopVolumePlaying() {
    final playToken = _playToken;
    _playToken = null;

    if (playToken != null) {
      _audioplayer.cancelByToken(playToken);
    }
  }

  void _onVolumeStart(AudioEntry entry, double value) async {
    _stopVolumePlaying();

    final file = File(entry.path);

    if (file.existsSync()) {
      _playToken = await _audioplayer.playFileInfinitely(file.path,
          volume: entry.volume);
    }
  }

  void _selectFile(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
        dialogTitle:
            context.localizations.reaction_play_audios_select_files_dialog,
        type: FileType.custom,
        allowedExtensions: ['wav', 'mp3'],
        allowMultiple: true);

    final paths = result?.files
            .where((f) => f.path != null)
            .map((f) => f.path!)
            .toList() ??
        [];

    setState(() {
      _action.audios.addAll(paths.map((p) => AudioEntry(path: p)));
      widget.changesCallback();
    });
  }

  void _onVolumeChange(AudioEntry file, double v) {
    setState(() {
      file.volume.set(v);
    });
  }

  void _handleDeleteClick(AudioEntry entry) {
    setState(() {
      _action.audios.remove(entry);
      widget.changesCallback();
    });
  }

  void _handleCountEdited(int value) {
    setState(() {
      _action.count = value == -1 ? null : value;
      widget.changesCallback();
    });
  }
}