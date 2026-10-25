import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:twitch_listener/core/extensions.dart';
import 'package:twitch_listener/generated/assets.dart';
import 'package:twitch_listener/ui/outline_icons.dart';
import 'package:twitch_listener/ui/simple_icon.dart';
import 'package:twitch_listener/ui/simple_indicator.dart';
import 'package:twitch_listener/ui/themes.dart';
import 'package:twitch_listener/twitch/reward_form_field.dart';

class RewardColorPicker extends StatefulWidget {
  final TextEditingController controller;
  final bool enabled;
  final int cost;

  const RewardColorPicker({
    super.key,
    required this.controller,
    required this.cost,
    this.enabled = true,
  });

  @override
  State<RewardColorPicker> createState() => _RewardColorPickerState();
}

class _RewardColorPickerState extends State<RewardColorPicker> {
  static const _presets = [
    0xFF6441AD,
    0xFF9146FF,
    0xFF3B82F6,
    0xFF06B6D4,
    0xFF10B981,
    0xFFEAB308,
    0xFFF97316,
    0xFFEF4444,
    0xFFEC4899,
    0xFF64748B,
  ];
  final _planeFocus = FocusNode();
  late HSVColor _color;
  bool _writing = false;

  static Color? _parse(String text) =>
      RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(text.trim())
      ? Color(int.parse('FF${text.trim().substring(1)}', radix: 16))
      : null;
  static String _hex(Color color) =>
      '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  @override
  void initState() {
    super.initState();
    _color = HSVColor.fromColor(
      _parse(widget.controller.text) ?? const Color(0xFF6441AD),
    );
    widget.controller.addListener(_readHex);
  }

  @override
  void didUpdateWidget(covariant RewardColorPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_readHex);
      widget.controller.addListener(_readHex);
      _readHex();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_readHex);
    _planeFocus.dispose();
    super.dispose();
  }

  void _readHex() {
    if (_writing) return;
    final parsed = _parse(widget.controller.text);
    if (parsed != null) setState(() => _color = HSVColor.fromColor(parsed));
  }

  void _select(HSVColor value) {
    if (!widget.enabled) return;
    setState(() => _color = value);
    final hex = _hex(value.toColor());
    _writing = true;
    widget.controller.value = TextEditingValue(
      text: hex,
      selection: TextSelection.collapsed(offset: hex.length),
    );
    _writing = false;
  }

  void _selectPoint(Offset point, Size size) {
    _planeFocus.requestFocus();
    _select(
      _color
          .withSaturation((point.dx / size.width).clamp(0, 1))
          .withValue((1 - point.dy / size.height).clamp(0, 1)),
    );
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (!widget.enabled ||
        (event is! KeyDownEvent && event is! KeyRepeatEvent)) {
      return KeyEventResult.ignored;
    }
    final step = HardwareKeyboard.instance.isShiftPressed ? .1 : .01;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight) {
      _select(
        _color.withSaturation(
          (_color.saturation +
                  (key == LogicalKeyboardKey.arrowLeft ? -step : step))
              .clamp(0, 1),
        ),
      );
    } else if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown) {
      _select(
        _color.withValue(
          (_color.value + (key == LogicalKeyboardKey.arrowDown ? -step : step))
              .clamp(0, 1),
        ),
      );
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.localizations;
    final current = _color.toColor();
    final plane = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, 156);
            return Semantics(
              label: l10n.twitch_rewards_color_saturation,
              value:
                  '${(_color.saturation * 100).round()}%, ${(_color.value * 100).round()}%',
              increasedValue:
                  '${(_color.saturation * 100).round()}%, ${((_color.value + .05).clamp(0, 1) * 100).round()}%',
              decreasedValue:
                  '${(_color.saturation * 100).round()}%, ${((_color.value - .05).clamp(0, 1) * 100).round()}%',
              enabled: widget.enabled,
              onIncrease: widget.enabled
                  ? () => _select(
                      _color.withValue((_color.value + .05).clamp(0, 1)),
                    )
                  : null,
              onDecrease: widget.enabled
                  ? () => _select(
                      _color.withValue((_color.value - .05).clamp(0, 1)),
                    )
                  : null,
              child: Focus(
                focusNode: _planeFocus,
                canRequestFocus: widget.enabled,
                onKeyEvent: _handleKey,
                onFocusChange: (_) => setState(() {}),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _planeFocus.hasFocus
                          ? theme.borderActive
                          : theme.border,
                      width: 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: GestureDetector(
                      key: const ValueKey('reward-color-plane'),
                      behavior: HitTestBehavior.opaque,
                      onPanDown: widget.enabled
                          ? (details) =>
                                _selectPoint(details.localPosition, size)
                          : null,
                      onPanUpdate: widget.enabled
                          ? (details) =>
                                _selectPoint(details.localPosition, size)
                          : null,
                      child: CustomPaint(
                        size: size,
                        painter: _ColorPlanePainter(_color),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const Gap(8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 12,
            padding: EdgeInsets.zero,
            trackShape: const _HueTrackShape(),
            thumbColor: Colors.white,
            overlayShape: SliderComponentShape.noOverlay,
            thumbShape: const RoundSliderThumbShape(
              enabledThumbRadius: 8,
              elevation: 1,
              pressedElevation: 2,
            ),
          ),
          child: Slider(
            key: const ValueKey('reward-color-hue'),
            label: l10n.twitch_rewards_color_hue,
            semanticFormatterCallback: (hue) =>
                '${l10n.twitch_rewards_color_hue}: ${hue.round()}°',
            max: 360,
            value: _color.hue,
            onChanged: widget.enabled
                ? (hue) => _select(_color.withHue(hue))
                : null,
          ),
        ),
      ],
    );
    final preview = Container(
      key: const ValueKey('reward-color-preview'),
      height: 78,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: current,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SimpleIcon.simpleSquare(
            OutlineIcons.reward,
            size: 24,
            color: current.computeLuminance() > .45
                ? Colors.black
                : Colors.white,
          ),
          const Gap(8),
          SimpleIndicator(
            text: l10n.x_points(widget.cost),
            theme: theme,
            style: IndicatorStyle.neutral,
            fontSize: 11,
          ),
        ],
      ),
    );
    final hex = RewardFormField(
      controller: widget.controller,
      label: l10n.twitch_rewards_color_hex,
      enabled: widget.enabled,
      maxLength: 7,
      validator: (value) => _parse(value ?? '') == null
          ? l10n.twitch_rewards_color_invalid
          : null,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 480 &&
                MediaQuery.textScalerOf(context).scale(1) <= 1.3) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: plane),
                  const Gap(16),
                  SizedBox(
                    width: 156,
                    child: Column(children: [preview, const Gap(8), hex]),
                  ),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [plane, const Gap(8), preview, const Gap(8), hex],
            );
          },
        ),
        const Gap(8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final preset in _presets) _swatch(Color(preset), theme),
          ],
        ),
      ],
    );
  }

  Widget _swatch(Color color, ThemeData theme) {
    final selected = _hex(color) == _hex(_color.toColor());
    final hex = _hex(color);
    return Semantics(
      button: true,
      selected: selected,
      label: hex,
      enabled: widget.enabled,
      child: Tooltip(
        message: hex,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? theme.accentColor : theme.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Material(
            color: color,
            shape: const CircleBorder(),
            child: InkWell(
              key: ValueKey('reward-color-$hex'),
              customBorder: const CircleBorder(),
              onTap: widget.enabled
                  ? () => _select(HSVColor.fromColor(color))
                  : null,
              child: SizedBox(
                width: 26,
                height: 26,
                child: selected
                    ? SimpleIcon.simpleSquare(
                        Assets.assetsIcCheckWhite16dp,
                        size: 16,
                        color: color.computeLuminance() > .45
                            ? Colors.black
                            : Colors.white,
                      )
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ColorPlanePainter extends CustomPainter {
  final HSVColor color;
  const _ColorPlanePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white,
            HSVColor.fromAHSV(1, color.hue, 1, 1).toColor(),
          ],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black],
        ).createShader(rect),
    );
    final marker = Offset(
      (color.saturation * size.width).clamp(7, size.width - 7),
      ((1 - color.value) * size.height).clamp(7, size.height - 7),
    );
    canvas.drawCircle(
      marker,
      7,
      Paint()..color = Colors.black.withValues(alpha: .5),
    );
    canvas.drawCircle(marker, 5.5, Paint()..color = Colors.white);
    canvas.drawCircle(marker, 3.5, Paint()..color = color.toColor());
  }

  @override
  bool shouldRepaint(_ColorPlanePainter oldDelegate) =>
      color != oldDelegate.color;
}

class _HueTrackShape extends RoundedRectSliderTrackShape {
  const _HueTrackShape();

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 2,
  }) {
    final rect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    final colors = [
      for (final hue in [0, 60, 120, 180, 240, 300, 360])
        HSVColor.fromAHSV(1, hue.toDouble(), 1, 1).toColor(),
    ];
    context.canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(6)),
      Paint()
        ..shader = LinearGradient(
          colors: textDirection == TextDirection.ltr
              ? colors
              : colors.reversed.toList(),
        ).createShader(rect),
    );
  }
}
