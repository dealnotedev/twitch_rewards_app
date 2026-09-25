import 'dart:io';

import 'package:path/path.dart' as p;

typedef MusicFileProducer = Future<File> Function(Directory stagingDirectory);

class MusicFileCache {
  static const profileName = 'youtube-native-audio-v1';
  static const _stagingDirectoryName = '.staging';
  static const _stagingMaxAge = Duration(days: 1);

  final Directory rootDirectory;
  final int maxBytes;

  final Set<String> _usedThisSession = {};
  Future<void>? _initialization;

  MusicFileCache({required this.rootDirectory, required this.maxBytes});

  Future<String> obtain({
    required String videoId,
    required MusicFileProducer produce,
  }) async {
    _validateVideoId(videoId);
    await _ensureInitialized();

    final target = _fileFor(videoId);
    if (await _isValid(target)) {
      await _touch(target);
      _usedThisSession.add(_normalize(target.path));
      return target.path;
    }

    await _deleteIfPresent(target);

    final stagingRoot = _stagingDirectory;
    await stagingRoot.create(recursive: true);
    final stagingDirectory = await stagingRoot.createTemp('download-');

    try {
      final produced = await produce(stagingDirectory);
      if (!_isInside(produced, stagingDirectory)) {
        throw StateError('Music producer returned a file outside staging');
      }
      if (!await _isValid(produced)) {
        throw StateError('Music producer did not create a playable file');
      }

      await target.parent.create(recursive: true);
      try {
        await produced.rename(target.path);
      } on FileSystemException {
        if (!await _isValid(target)) rethrow;
        await _deleteIfPresent(produced);
      }

      await _touch(target);
      _usedThisSession.add(_normalize(target.path));
      await _prune();
      return target.path;
    } finally {
      await _deleteDirectoryIfPresent(stagingDirectory);
    }
  }

  Directory get _profileDirectory =>
      Directory('${rootDirectory.path}${Platform.pathSeparator}$profileName');

  Directory get _stagingDirectory => Directory(
        '${_profileDirectory.path}'
        '${Platform.pathSeparator}$_stagingDirectoryName',
      );

  File _fileFor(String videoId) =>
      File('${_profileDirectory.path}${Platform.pathSeparator}$videoId.media');

  Future<void> _ensureInitialized() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    await _profileDirectory.create(recursive: true);
    await _stagingDirectory.create(recursive: true);
    await _removeStaleStagingEntries();
    await _prune();
  }

  Future<void> _removeStaleStagingEntries() async {
    final cutoff = DateTime.now().subtract(_stagingMaxAge);
    await for (final entity in _stagingDirectory.list(followLinks: false)) {
      try {
        final modified = (await entity.stat()).modified;
        if (modified.isBefore(cutoff)) {
          if (entity is Directory) {
            await entity.delete(recursive: true);
          } else {
            await entity.delete();
          }
        }
      } on FileSystemException {
        // Cleanup is best effort; a different process may own the entry.
      }
    }
  }

  Future<void> _prune() async {
    if (maxBytes <= 0) return;

    final entries = <_CacheFile>[];
    var totalBytes = 0;
    await for (final entity in _profileDirectory.list(followLinks: false)) {
      if (entity is! File || !entity.path.toLowerCase().endsWith('.media')) {
        continue;
      }

      try {
        final stat = await entity.stat();
        if (stat.size <= 0) {
          await entity.delete();
          continue;
        }
        totalBytes += stat.size;
        entries.add(
          _CacheFile(file: entity, size: stat.size, modified: stat.modified),
        );
      } on FileSystemException {
        // Cache maintenance must not prevent playback.
      }
    }

    if (totalBytes <= maxBytes) return;
    entries.sort((a, b) => a.modified.compareTo(b.modified));

    for (final entry in entries) {
      if (totalBytes <= maxBytes) break;
      if (_usedThisSession.contains(_normalize(entry.file.path))) continue;

      try {
        await entry.file.delete();
        totalBytes -= entry.size;
      } on FileSystemException {
        // Cache maintenance is best effort.
      }
    }
  }

  static Future<bool> _isValid(File file) async {
    try {
      return await file.exists() && await file.length() > 0;
    } on FileSystemException {
      return false;
    }
  }

  static Future<void> _touch(File file) async {
    try {
      await file.setLastModified(DateTime.now());
    } on FileSystemException {
      // A valid cache hit remains usable if its timestamp cannot be updated.
    }
  }

  static Future<void> _deleteIfPresent(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // Let a later filesystem operation report the actionable failure.
    }
  }

  static Future<void> _deleteDirectoryIfPresent(Directory directory) async {
    try {
      if (await directory.exists()) await directory.delete(recursive: true);
    } on FileSystemException {
      // Staging cleanup is best effort.
    }
  }

  static bool _isInside(File file, Directory directory) {
    final root = '${_normalize(directory.path)}/';
    return _normalize(file.path).startsWith(root);
  }

  static String _normalize(String path) {
    final absolute = p.normalize(p.absolute(path)).replaceAll('\\', '/');
    return Platform.isWindows ? absolute.toLowerCase() : absolute;
  }

  static void _validateVideoId(String videoId) {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(videoId)) {
      throw ArgumentError.value(videoId, 'videoId', 'Invalid YouTube video ID');
    }
  }
}

Directory defaultMusicCacheDirectory() {
  String? baseDirectory;
  if (Platform.isWindows) {
    baseDirectory = Platform.environment['LOCALAPPDATA'];
  } else if (Platform.isMacOS) {
    final home = Platform.environment['HOME'];
    if (home != null && home.isNotEmpty) {
      baseDirectory = '$home${Platform.pathSeparator}Library'
          '${Platform.pathSeparator}Caches';
    }
  } else if (Platform.isLinux) {
    baseDirectory = Platform.environment['XDG_CACHE_HOME'];
    if (baseDirectory == null || baseDirectory.isEmpty) {
      final home = Platform.environment['HOME'];
      if (home != null && home.isNotEmpty) {
        baseDirectory = '$home${Platform.pathSeparator}.cache';
      }
    }
  }

  if (baseDirectory == null || baseDirectory.isEmpty) {
    baseDirectory = Directory.systemTemp.path;
  }

  return Directory(
    '$baseDirectory${Platform.pathSeparator}twitch_listener'
    '${Platform.pathSeparator}music-cache',
  );
}

class _CacheFile {
  final File file;
  final int size;
  final DateTime modified;

  const _CacheFile({
    required this.file,
    required this.size,
    required this.modified,
  });
}
