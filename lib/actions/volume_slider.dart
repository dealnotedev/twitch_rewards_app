import 'package:flutter/material.dart';
import 'package:twitch_listener/observable_value.dart';
import 'package:twitch_listener/themes.dart';

class VolumeSlider extends StatelessWidget {
  final ThemeData theme;
  final ObservableValue<double> volume;

  final ValueChanged<double>? onChangeStart;
  final ValueChanged<double>? onChangeEnd;
  final ValueChanged<double>? onChangeChange;

  final double width;

  const VolumeSlider(
      {super.key,
      required this.theme,
      required this.volume,
      this.width = 84,
      this.onChangeStart,
      this.onChangeEnd,
      this.onChangeChange});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
        width: width,
        child: Stack(
          alignment: Alignment.center,
          children: [
            _createSlider(context, theme),
            _createSliderValues(context, theme)
          ],
        ));
  }

  Widget _createSliderValues(BuildContext context, ThemeData theme) {
    final value = volume.current;
    final percentage = '${(value * 100.0).round()}%';

    const style =
        TextStyle(fontSize: 10, fontWeight: FontWeight.w500, height: 1);
    return IgnorePointer(
      child: Row(
        children: [
          Expanded(
              child: Visibility(
                  visible: value > 1.5,
                  child: Text(
                    percentage,
                    textAlign: TextAlign.center,
                    style:
                        style.copyWith(color: theme.textColorPrimaryInverted),
                  ))),
          Expanded(
              child: Visibility(
                  visible: value <= 1.5,
                  child: Text(
                    percentage,
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
            value: volume.current,
            onChangeStart: onChangeStart,
            onChangeEnd: onChangeEnd,
            onChanged: onChangeChange));
  }
}
