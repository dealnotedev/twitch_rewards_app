import 'dart:io';

import 'package:flutter/services.dart';

Future<void> loadTestFonts() async {
  if (Platform.isWindows) {
    final fonts = '${Platform.environment['WINDIR']}/Fonts';
    await (FontLoader('Consolas')
          ..addFont(File('$fonts/consola.ttf').readAsBytes().then(ByteData.sublistView)))
        .load();
    for (final name in ['Roboto', 'Segoe UI']) {
      await (FontLoader(name)
            ..addFont(
              File('$fonts/segoeui.ttf')
                  .readAsBytes()
                  .then(ByteData.sublistView),
            )
            ..addFont(
              File('$fonts/seguisb.ttf')
                  .readAsBytes()
                  .then(ByteData.sublistView),
            ))
          .load();
    }
  }
  await (FontLoader(
    'MaterialIcons',
  )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
}
