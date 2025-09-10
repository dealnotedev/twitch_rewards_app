import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:twitch_listener/audioplayer.dart';
import 'package:twitch_listener/buttons.dart';
import 'package:twitch_listener/extensions.dart';
import 'package:twitch_listener/generated/assets.dart';
import 'package:twitch_listener/reward.dart';
import 'package:twitch_listener/ripple_icon.dart';
import 'package:twitch_listener/simple_icon.dart';
import 'package:twitch_listener/themes.dart';

class PlayAudiosWidget extends StatefulWidget {
  final RewardAction action;
  final Audioplayer audioplayer;

  const PlayAudiosWidget({super.key, required this.action, required this.audioplayer});

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<PlayAudiosWidget> {
  late final RewardAction _action;

  @override
  void initState() {
    _action = widget.action;
    super.initState();
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
              onTap: () {},
            )
          ],
        ),
        const Gap(8),
        if (files.isEmpty) ...[
          const Gap(8),
          SizedBox(
            width: double.infinity,
            child: Text(
              context.localizations.reaction_play_audios_no_files,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: theme.textColorSecondary),
            ),
          )
        ] else
          ...files.mapIndexed((index, f) =>
              _createAudioFileWidget(context, theme, entry: f, index: index))
      ],
    );
  }

  Widget _createAudioFileWidget(BuildContext context, ThemeData theme,
      {required AudioEntry entry, required int index}) {
    return Container(
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.dividerColor, width: 0.5)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          const Gap(8),
          SimpleIcon.simpleSquare(Assets.assetsIcAudioFileWhite16dp,
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
          SizedBox(
              width: 84,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  _createSlider(context, theme, file: entry),
                  _createSliderValues(context, theme, entry: entry)
                ],
              )),
          const Gap(8),
          RippleIcon(
              borderRadius: BorderRadius.circular(8),
              icon: Assets.assetsIcDeleteWhite16dp,
              onTap: () {},
              size: 16,
              color: theme.textColorPrimary),
        ],
      ),
    );
  }

  Widget _createSliderValues(BuildContext context, ThemeData theme,
      {required AudioEntry entry}) {
    final volume = entry.volume.current;
    final volumePercentage = '${(volume * 100.0).round()}%';

    const style =
        TextStyle(fontSize: 10, fontWeight: FontWeight.w500, height: 1);
    return Row(
      children: [
        Expanded(
            child: Visibility(
                visible: volume > 1.5,
                child: Text(
                  volumePercentage,
                  textAlign: TextAlign.center,
                  style: style.copyWith(color: theme.textColorPrimaryInverted),
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
    );
  }

  Widget _createSlider(BuildContext context, ThemeData theme,
      {required AudioEntry file}) {
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
            trackGap: 0,
            overlayColor: Colors.transparent,
            minThumbSeparation: 0,
            trackShape: const RoundedRectSliderTrackShape(),
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
            value: file.volume.current,
            onChangeStart: (v) => _onVolumeStart(file, v),
            onChangeEnd: (v) => _onVolumeEnd(file, v),
            onChanged: (v) => _onVolumeChange(file, v)));
  }

  void _onVolumeStart(AudioEntry file, double v) {}

  void _onVolumeEnd(AudioEntry file, double v) {}

  void _onVolumeChange(AudioEntry file, double v) {
    setState(() {
      file.volume.set(v);
    });
  }
}
