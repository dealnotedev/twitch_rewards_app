import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'update_package.dart';
import 'update_failure.dart';

/// Replaces archive roots while protecting the updater. The journal is flushed before any
/// move so a subsequent updater run can recover an interrupted installation.
final class Installation {
  Installation(String directory) : root = p.normalize(p.absolute(directory)) {
    if (p.dirname(root) == root) {
      throw const UpdateFileFailure(UpdateIssue.invalidInstallation);
    }
    for (
      var parent = root;
      p.dirname(parent) != parent;
      parent = p.dirname(parent)
    ) {
      if (FileSystemEntity.typeSync(parent, followLinks: false) ==
          FileSystemEntityType.link) {
        throw const UpdateFileFailure(UpdateIssue.linksUnsupported);
      }
    }
    rejectLinks(work);
    if (!needsRecovery &&
        (!File(p.join(root, listenerExecutable)).existsSync() ||
            !File(p.join(root, manifestName)).existsSync())) {
      throw const UpdateFileFailure(UpdateIssue.invalidInstallation);
    }
  }

  final String root;
  String get work => p.join(root, '.listener-update');
  String get stage => p.join(work, 'stage');
  String get archive => p.join(work, 'download.zip');
  String get _backup => p.join(work, 'backup');
  String get _journal => p.join(work, 'transaction.json');
  bool get needsRecovery => File(_journal).existsSync();

  void prepare() {
    if (needsRecovery) {
      throw const UpdateFileFailure(UpdateIssue.recoveryRequired);
    }
    Directory(work).createSync(recursive: true);
    cleanWork();
  }

  void apply(PackageManifest package, {void Function(String)? afterInstall}) {
    if (needsRecovery) {
      throw const UpdateFileFailure(UpdateIssue.recoveryRequired);
    }
    final previous = PackageManifest.read(root).roots;
    final entries = <Map<String, dynamic>>[];
    final names = {
      for (final name in [...previous, ...package.roots])
        name.toLowerCase(): name,
    };
    for (final name in names.values) {
      if (!isReplaceableRoot(name)) {
        throw const UpdateFailure(UpdateIssue.unsafePath);
      }
      final target = safePath(root, name);
      rejectLinks(target);
      entries.add({'name': name, 'hadOriginal': _exists(target)});
    }
    Directory(_backup).createSync(recursive: true);
    File(_journal).writeAsStringSync(
      jsonEncode({'schema': 1, 'entries': entries}),
      flush: true,
    );
    try {
      for (final entry in entries) {
        final name = entry['name'] as String;
        final destination = safePath(root, name);
        if (entry['hadOriginal'] == true) {
          _move(destination, safePath(_backup, name));
        }
        final source = safePath(stage, name);
        if (_exists(source)) _move(source, destination);
        afterInstall?.call(name);
      }
      File(_journal).deleteSync(); // Commit point.
    } catch (_) {
      recover();
      rethrow;
    }
  }

  void recover() {
    if (!needsRecovery) return;
    rejectLinks(work);
    final json =
        jsonDecode(File(_journal).readAsStringSync()) as Map<String, dynamic>;
    final entries = (json['entries'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    if (json['schema'] != 1 ||
        entries.any(
          (entry) =>
              entry['name'] is! String ||
              !isReplaceableRoot(entry['name'] as String) ||
              entry['hadOriginal'] is! bool,
        ) ||
        entries
                .map((entry) => (entry['name'] as String).toLowerCase())
                .toSet()
                .length !=
            entries.length) {
      throw const UpdateFailure(UpdateIssue.invalidJournal);
    }
    for (final entry in entries.reversed) {
      final name = entry['name'] as String;
      final destination = safePath(root, name);
      final backup = safePath(_backup, name);
      if (_exists(backup)) {
        _delete(destination);
        _move(backup, destination);
      } else if (entry['hadOriginal'] == false) {
        _delete(destination);
      }
    }
    File(_journal).deleteSync();
  }

  void cleanWork() {
    if (needsRecovery) return;
    rejectLinks(work);
    _delete(stage);
    _delete(_backup);
    _delete(archive);
  }

  static bool _exists(String path) =>
      FileSystemEntity.typeSync(path, followLinks: false) !=
      FileSystemEntityType.notFound;
  static void _move(String source, String destination) {
    if (Directory(source).existsSync()) {
      Directory(source).renameSync(destination);
    } else {
      File(source).renameSync(destination);
    }
  }

  static void _delete(String path) {
    rejectLinks(path);
    if (Directory(path).existsSync()) {
      Directory(path).deleteSync(recursive: true);
    } else if (File(path).existsSync()) {
      File(path).deleteSync();
    }
  }
}
