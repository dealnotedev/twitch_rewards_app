import 'package:flutter/material.dart';

class DefaultInputDecoration extends InputDecoration {
  const DefaultInputDecoration({String? hintText})
      : super(
          hintText: hintText,
          hintStyle: const TextStyle(fontSize: 14, color: Color(0x40ffffff)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          fillColor: const Color(0xFF272E37),
          filled: true,
          isDense: true,
        );
}
