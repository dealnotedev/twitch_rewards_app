import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

import 'app_version.dart';
import 'update_failure.dart';

const listenerExecutable = 'twitch_listener.exe';
const manifestName = 'listener-update.json';

bool _safePart(String part) =>
    part.isNotEmpty &&
    part != '.' &&
    part != '..' &&
    !part.endsWith('.') &&
    !part.endsWith(' ') &&
    !RegExp(r'[<>:"|?*\x00-\x1f]').hasMatch(part) &&
    !RegExp(
      r'^(CON|PRN|AUX|NUL|COM[0-9]|LPT[0-9])(?:\.|$)',
      caseSensitive: false,
    ).hasMatch(part);

bool isUpdaterRoot(String name) => name.toLowerCase() == 'updater';
bool isReplaceableRoot(String name) =>
    _safePart(name) &&
    !name.contains('/') &&
    !name.contains(r'\') &&
    !isUpdaterRoot(name) &&
    name.toLowerCase() != '.listener-update';

String safePath(String root, String relative) {
  final parts = relative.replaceAll(r'\', '/').split('/');
  if (parts.any((part) => !_safePart(part))) {
    throw const UpdateFailure(UpdateIssue.unsafePath);
  }
  final result = p.normalize(p.joinAll([p.absolute(root), ...parts]));
  if (!p.isWithin(p.absolute(root), result)) {
    throw const UpdateFailure(UpdateIssue.unsafePath);
  }
  return result;
}

/// Does not follow symbolic links or junctions during inspection or deletion.
void rejectLinks(String path) {
  final type = FileSystemEntity.typeSync(path, followLinks: false);
  if (type == FileSystemEntityType.link) {
    throw const UpdateFileFailure(UpdateIssue.linksUnsupported);
  }
  if (type == FileSystemEntityType.directory) {
    for (final child in Directory(path).listSync(followLinks: false)) {
      rejectLinks(child.path);
    }
  }
}

final class PackageManifest {
  const PackageManifest({required this.version, required this.roots});
  final AppVersion version;
  final List<String> roots;

  factory PackageManifest.read(String directory) {
    final json = jsonDecode(
      File(p.join(directory, manifestName)).readAsStringSync(),
    ) as Map<String, dynamic>;
    final roots = (json['roots'] as List<dynamic>).cast<String>();
    if (json['schema'] != 1 ||
        json['application'] != 'twitch_listener' ||
        roots.any((name) => !isReplaceableRoot(name) && !isUpdaterRoot(name)) ||
        roots.map((name) => name.toLowerCase()).toSet().length !=
            roots.length) {
      throw const UpdateFailure(UpdateIssue.invalidPackage);
    }
    return PackageManifest(
      version: AppVersion.parse(json['version'] as String),
      roots: roots.where(isReplaceableRoot).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'schema': 1,
    'application': 'twitch_listener',
    'version': version.toString(),
    'roots': roots,
  };
}

PackageManifest extractPackage(
  String zipPath,
  String stage,
  AppVersion expected,
) {
  Directory(stage).createSync(recursive: true);
  rejectLinks(stage);
  final input = InputFileStream(zipPath);
  try {
    final decoder = ZipDecoder();
    final archive = decoder.decodeStream(input);
    final entries = decoder.directory.fileHeaders;
    if (entries.length > 30000) {
      throw const UpdateFailure(UpdateIssue.tooManyFiles);
    }
    final names = <String>{};
    var expanded = 0;
    for (final entry in entries) {
      final name = entry.filename
          .replaceAll(r'\', '/')
          .replaceFirst(RegExp(r'/$'), '');
      safePath(stage, name);
      final root = name.split('/').first;
      // An archive may include an updater, but its running files are never installed.
      if (isUpdaterRoot(root)) continue;
      if (!isReplaceableRoot(root) ||
          !names.add(name.toLowerCase()) ||
          ((entry.externalFileAttributes >> 16) & 0xf000) == 0xa000) {
        throw const UpdateFailure(UpdateIssue.invalidPackage);
      }
      expanded += entry.uncompressedSize;
      if (expanded > 2 * 1024 * 1024 * 1024) {
        throw const UpdateFailure(UpdateIssue.packageTooLarge);
      }
    }
    for (final entry in archive) {
      final name = entry.name
          .replaceAll(r'\', '/')
          .replaceFirst(RegExp(r'/$'), '');
      if (isUpdaterRoot(name.split('/').first)) continue;
      final target = safePath(stage, name);
      if (entry.isSymbolicLink) {
        throw const UpdateFailure(UpdateIssue.linksUnsupported);
      }
      if (entry.isDirectory) {
        Directory(target).createSync(recursive: true);
      } else {
        Directory(p.dirname(target)).createSync(recursive: true);
        final output = OutputFileStream(target);
        try {
          entry.writeContent(output);
        } finally {
          output.closeSync();
        }
      }
    }
    final manifest = PackageManifest.read(stage);
    if (!manifest.version.matchesRelease(expected)) {
      throw const UpdateFailure(UpdateIssue.versionMismatch);
    }
    for (final required in [
      listenerExecutable,
      'flutter_windows.dll',
      'libmpv-2.dll',
      'sqlite3.dll',
      'tools/yt-dlp.exe',
      'tools/deno.exe',
      'tools/ffmpeg.exe',
      'data/app.so',
      'data/icudtl.dat',
      'data/flutter_assets/AssetManifest.bin',
    ]) {
      final file = File(safePath(stage, required));
      if (!file.existsSync() || file.lengthSync() == 0) {
        throw const UpdateFailure(UpdateIssue.missingRuntime);
      }
    }
    // Actual archive contents are authoritative; new files do not need an allowlist.
    final roots = Directory(stage)
        .listSync(followLinks: false)
        .map((entry) => p.basename(entry.path))
        .where(isReplaceableRoot)
        .toList();
    final package = PackageManifest(version: manifest.version, roots: roots);
    File(p.join(stage, manifestName))
        .writeAsStringSync(jsonEncode(package.toJson()), flush: true);
    return package;
  } finally {
    input.closeSync();
  }
}
