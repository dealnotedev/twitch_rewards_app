import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'update_check.dart';

class UpdateController extends ChangeNotifier {
  UpdateController({
    Future<String?> Function()? check,
    Future<void> Function(String locale, String theme)? launch,
  }) : _check = check == null ? UpdateCheck() : null,
       _launch = launch ?? _openUpdater {
    _load(check ?? _check!.newerVersion);
  }

  final UpdateCheck? _check;
  final Future<void> Function(String locale, String theme) _launch;
  bool _disposed = false;
  String? version;
  bool dismissed = false;
  bool opening = false;
  bool launchFailed = false;

  static Future<void> _openUpdater(String locale, String theme) =>
      const MethodChannel(
        'listener/update',
      ).invokeMethod<void>('openUpdater', {'locale': locale, 'theme': theme});

  Future<void> _load(Future<String?> Function() check) async {
    try {
      final available = await check();
      if (_disposed) return;
      version = available;
      notifyListeners();
    } catch (_) {
      // Update checks never interrupt application startup.
    }
  }

  Future<void> open({
    required String locale,
    required Brightness brightness,
  }) async {
    if (_disposed || opening) return;
    opening = true;
    launchFailed = false;
    notifyListeners();
    try {
      await _launch(locale, brightness.name);
    } catch (_) {
      if (!_disposed) launchFailed = true;
    } finally {
      if (!_disposed) {
        opening = false;
        notifyListeners();
      }
    }
  }

  void dismiss() {
    if (_disposed) return;
    dismissed = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _check?.dispose();
    super.dispose();
  }
}
