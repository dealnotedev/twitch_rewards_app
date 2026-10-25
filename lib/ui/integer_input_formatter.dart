import 'package:flutter/services.dart';

/// Accepts whole non-negative integers without silently changing pasted values.
class UnsignedIntegerInputFormatter extends TextInputFormatter {
  final int? maxValue;
  static final _nonDigits = RegExp(r'[^0-9]');

  const UnsignedIntegerInputFormatter({this.maxValue})
    : assert(maxValue == null || maxValue >= 0);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;
    if (_nonDigits.hasMatch(text)) return oldValue;
    final value = int.tryParse(text);
    if (value == null || (maxValue != null && value > maxValue!)) {
      return oldValue;
    }
    return newValue;
  }
}
