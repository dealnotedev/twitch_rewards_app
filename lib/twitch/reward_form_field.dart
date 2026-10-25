import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:twitch_listener/ui/custom_switch.dart';
import 'package:twitch_listener/ui/integer_input_formatter.dart';
import 'package:twitch_listener/ui/text_field_decoration.dart';
import 'package:twitch_listener/ui/themes.dart';

/// Adds form validation and a label to the application's existing input chrome.
class RewardFormField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final bool enabled;
  final bool numeric;
  final TextInputAction? textInputAction;
  final int lines;
  final int? maxLength;
  final String? Function(String?)? validator;

  const RewardFormField({
    super.key,
    required this.controller,
    required this.label,
    this.enabled = true,
    this.numeric = false,
    this.textInputAction,
    this.lines = 1,
    this.maxLength,
    this.validator,
  });

  @override
  State<RewardFormField> createState() => _RewardFormFieldState();
}

class _RewardFormFieldState extends State<RewardFormField> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: theme.textColorPrimary,
          ),
        ),
        const Gap(6),
        TextFieldDecoration(
          theme: theme,
          controller: widget.controller,
          focusNode: _focus,
          hint: '',
          clearable: false,
          builder: (context, decoration, style) => TextFormField(
            controller: widget.controller,
            focusNode: _focus,
            enabled: widget.enabled,
            validator: widget.validator,
            maxLength: widget.maxLength,
            buildCounter: (
              context, {
              required currentLength,
              required isFocused,
              maxLength,
            }) => null,
            maxLines: widget.numeric ? 1 : widget.lines,
            keyboardType: widget.numeric
                ? const TextInputType.numberWithOptions(
                    signed: false,
                    decimal: false,
                  )
                : widget.lines > 1
                ? TextInputType.multiline
                : TextInputType.text,
            inputFormatters: widget.numeric
                ? const [UnsignedIntegerInputFormatter()]
                : null,
            textInputAction:
                widget.textInputAction ??
                (widget.numeric ? TextInputAction.next : null),
            autocorrect: !widget.numeric,
            enableSuggestions: !widget.numeric,
            enableIMEPersonalizedLearning: !widget.numeric,
            smartDashesType: widget.numeric ? SmartDashesType.disabled : null,
            smartQuotesType: widget.numeric ? SmartQuotesType.disabled : null,
            style: style,
            decoration: decoration,
          ),
        ),
      ],
    );
  }
}

class RewardSwitchField extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const RewardSwitchField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    void toggle() => onChanged?.call(!value);
    return Row(
      children: [
        Semantics(
          label: label,
          toggled: value,
          enabled: onChanged != null,
          onTap: onChanged == null ? null : toggle,
          child: ExcludeSemantics(
            child: IgnorePointer(
              ignoring: onChanged == null,
              child: Opacity(
                opacity: onChanged == null ? .5 : 1,
                child: CustomSwitch(
                  theme: theme,
                  value: value,
                  onToggle: (next) => onChanged?.call(next),
                ),
              ),
            ),
          ),
        ),
        const Gap(8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: onChanged == null
                  ? theme.textColorSecondary
                  : theme.textColorPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
