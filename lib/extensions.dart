import 'dart:async';

import 'package:flutter/material.dart';
import 'package:twitch_listener/l10n/app_localizations.dart';

extension MyIterable<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;

  T? firstWhereOrNull(bool Function(T element) test) {
    final list = where(test);
    return list.isEmpty ? null : list.first;
  }
}

extension ContextExt on BuildContext {
  AppLocalizations get localizations => AppLocalizations.of(this)!;
}

extension TextEditingControllerStreamExt on TextEditingController {
  Stream<String> stream() {
    late StreamController<String> controllerStream;

    void listener() {
      controllerStream.add(text);
    }

    controllerStream = StreamController<String>(
      onListen: () {
        addListener(listener);
      },
      onCancel: () {
        removeListener(listener);
      },
    );

    return controllerStream.stream;
  }
}