import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:twitch_listener/generated/assets.dart';
import 'package:twitch_listener/ripple_icon.dart';
import 'package:twitch_listener/themes.dart';

class TextFieldDecoration extends StatefulWidget {
  final ThemeData theme;
  final TextFieldBuilder builder;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;

  final Widget? prefix;
  final bool clearable;

  const TextFieldDecoration(
      {super.key,
      this.prefix,
      required this.builder,
      required this.hint,
      required this.controller,
      required this.focusNode,
      required this.theme,
      this.clearable = true});

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<TextFieldDecoration> {
  late final FocusNode _focusNode;
  late final TextEditingController _controller;

  @override
  void initState() {
    _focusNode = widget.focusNode;
    _controller = widget.controller;

    _focusNode.addListener(_handleFocus);
    _controller.addListener(_handleEditing);
    super.initState();
  }

  @override
  void didUpdateWidget(covariant TextFieldDecoration oldWidget) {
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller.removeListener(_handleEditing);
      widget.controller.addListener(_handleEditing);
    }
    if (widget.focusNode != oldWidget.focusNode) {
      oldWidget.focusNode.removeListener(_handleFocus);
      widget.focusNode.addListener(_handleFocus);
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocus);
    _controller.removeListener(_handleEditing);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final style = TextStyle(fontSize: 13, color: theme.textColorPrimary);
    final prefix = widget.prefix;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        border: Border.all(
          strokeAlign: BorderSide.strokeAlignOutside,
          color: theme.borderActive.withValues(alpha: _focused ? 0.35 : 0.0),
          width: _focused ? 4.0 : 0.0,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
            color: theme.inputBackground,
            border: Border.all(
                strokeAlign: BorderSide.strokeAlignOutside,
                color: _focused ? theme.borderActive : theme.border,
                width: 0.5),
            borderRadius: BorderRadius.circular(8)),
        child: Row(
          children: [
            if (prefix != null) ...[
              const Gap(8),
              prefix,
              const Gap(8),
            ] else ...[
              const Gap(12)
            ],
            Expanded(
                child: widget.builder.call(
                    context,
                    InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        hintStyle:
                            style.copyWith(color: theme.textColorSecondary),
                        contentPadding: const EdgeInsets.symmetric(vertical: 4),
                        hintText: widget.hint),
                    style)),
            if (widget.clearable) ...[
              const Gap(8),
              Visibility(
                visible: _cleareable,
                maintainState: true,
                maintainSize: true,
                maintainAnimation: true,
                child: RippleIcon(
                    size: 16,
                    onTap: () {
                      _controller.text = '';
                      _focusNode.requestFocus();
                    },
                    padding: 4,
                    borderRadius: BorderRadius.circular(8),
                    icon: Assets.assetsIcCloseWhite16dp,
                    color: theme.textColorPrimary),
              ),
              const Gap(4)
            ] else ...[
              const Gap(12)
            ]
          ],
        ),
      ),
    );
  }

  void _handleEditing() {
    final cleareable = _controller.text.isNotEmpty;
    if (_cleareable != cleareable) {
      setState(() {
        _cleareable = cleareable;
      });
    }
  }

  bool _focused = false;
  bool _cleareable = false;

  void _handleFocus() {
    final focused = _focusNode.hasFocus;

    if (_focused != focused) {
      setState(() {
        _focused = focused;
      });
    }
  }
}

typedef TextFieldBuilder = Widget Function(
    BuildContext context, InputDecoration? decoration, TextStyle textStyle);
