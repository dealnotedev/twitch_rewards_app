import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:twitch_listener/reward.dart';

class RewardsStore {
  RewardsStore._(this._database);

  static const _databaseName = 'rewards.db';
  static const _migrationKey = 'shared_preferences_imported';

  final Database _database;

  static Future<RewardsStore> open({
    DatabaseFactory? factory,
    String? databasePath,
  }) async {
    factory ??= _defaultDatabaseFactory();

    if (databasePath == null) {
      final directory = await getApplicationSupportDirectory();
      await directory.create(recursive: true);
      databasePath = path.join(directory.path, _databaseName);
    }

    final database = await factory.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (database, version) async {
          await database.execute('''
            CREATE TABLE rewards (
              position INTEGER PRIMARY KEY,
              payload TEXT NOT NULL
            )
          ''');
          await database.execute('''
            CREATE TABLE metadata (
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL
            )
          ''');
        },
      ),
    );

    return RewardsStore._(database);
  }

  static DatabaseFactory _defaultDatabaseFactory() {
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      return databaseFactoryFfi;
    }
    return databaseFactory;
  }

  Future<Rewards> loadAndMigrate(String? legacyJson) async {
    await _database.transaction((transaction) async {
      final migration = await transaction.query(
        'metadata',
        columns: ['value'],
        where: 'key = ?',
        whereArgs: [_migrationKey],
        limit: 1,
      );

      if (migration.isNotEmpty) {
        return;
      }

      if (legacyJson != null) {
        final legacyRewards = Rewards.fromJson(jsonDecode(legacyJson));
        await _replaceRewards(transaction, legacyRewards);
      }

      await transaction.insert('metadata', {
        'key': _migrationKey,
        'value': '1',
      });
    });

    return load();
  }

  Future<Rewards> load() async {
    final rows = await _database.query('rewards', orderBy: 'position ASC');
    return Rewards(
      rewards: rows
          .map((row) => Reward.fromJson(jsonDecode(row['payload'] as String)))
          .toList(),
    );
  }

  Future<void> save(Rewards rewards) {
    return _database.transaction(
      (transaction) => _replaceRewards(transaction, rewards),
    );
  }

  static Future<void> _replaceRewards(
    DatabaseExecutor database,
    Rewards rewards,
  ) async {
    await database.delete('rewards');

    final batch = database.batch();
    for (var i = 0; i < rewards.rewards.length; i++) {
      batch.insert('rewards', {
        'position': i,
        'payload': jsonEncode(rewards.rewards[i].toJson()),
      });
    }
    await batch.commit(noResult: true);
  }

  Future<void> close() => _database.close();
}
