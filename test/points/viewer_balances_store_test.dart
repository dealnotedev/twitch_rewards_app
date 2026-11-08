import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:twitch_listener/points/viewer_balances_store.dart';
import 'package:twitch_listener/rewards/reward.dart';
import 'package:twitch_listener/rewards/rewards_store.dart';

void main() {
  setUpAll(sqfliteFfiInit);
  late Database database;
  late ViewerBalancesStore balances;

  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) => ViewerBalancesStore.createTable(db),
      ),
    );
    balances = ViewerBalancesStore(database);
  });
  tearDown(() async {
    await database.close();
    balances.dispose();
  });

  test(
    'loads balances with names, ordered by balance and then login',
    () async {
      await balances.credit('2', 10, username: 'zebra', displayName: 'Zebra');
      await balances.credit('3', 10, username: 'Alice', displayName: 'Alice');
      await balances.credit(
        '1',
        20,
        username: 'top',
        displayName: 'Top Viewer',
      );
      final rows = await balances.loadBalances();
      expect(rows.map((row) => row.viewerId), ['1', '3', '2']);
      expect(rows.first.username, 'top');
      expect(rows.first.displayName, 'Top Viewer');
      expect(rows.first.balance, 20);
      expect(rows[1].matches('  ALI  '), isTrue);
      expect(rows[1].matches('missing'), isFalse);
    },
  );

  test('only committed credits and debits notify balance observers', () async {
    var notifications = 0;
    final subscription = balances.changes.listen((_) => notifications++);
    addTearDown(subscription.cancel);
    final credited = balances.changes.first.then(
      (_) => balances.balanceOf('viewer'),
    );
    await balances.credit('viewer', 10);
    expect(await credited, 10);
    final debited = balances.changes.first.then(
      (_) => balances.balanceOf('viewer'),
    );
    await balances.debit('viewer', 3);
    expect(await debited, 7);
    await expectLater(balances.debit('viewer', 8), throwsStateError);
    expect(notifications, 2);
  });

  test(
    'parallel credits and debits keep exactly one integer balance',
    () async {
      expect(await balances.balanceOf('viewer'), 0);
      await balances.credit('viewer', 100);
      await Future.wait([
        for (var i = 0; i < 40; i++) ...[
          balances.credit('viewer', 3),
          balances.debit('viewer', 2),
        ],
      ]);
      expect(await balances.balanceOf('viewer'), 140);
      expect(await database.query('viewer_balances'), [
        {
          'viewer_id': 'viewer',
          'username': '',
          'display_name': '',
          'balance': 140,
        },
      ]);
    },
  );

  test('concurrent spending cannot overdraw the balance', () async {
    await balances.credit('viewer', 10);
    final accepted = await Future.wait([
      for (var i = 0; i < 30; i++) _attempt(balances.debit('viewer', 1)),
    ]);
    expect(accepted.where((value) => value), hasLength(10));
    expect(await balances.balanceOf('viewer'), 0);
    await expectLater(balances.debit('unknown', 1), throwsStateError);
    expect(await database.query('viewer_balances'), hasLength(1));
  });

  test(
    'checks headroom before arithmetic at the signed 64-bit limit',
    () async {
      const maximum = ViewerBalancesStore.maxBalance;
      await balances.credit('viewer', maximum - 1);
      final accepted = await Future.wait([
        _attempt(balances.credit('viewer', 1)),
        _attempt(balances.credit('viewer', 1)),
      ]);
      expect(accepted.where((value) => value), hasLength(1));
      expect(await balances.balanceOf('viewer'), maximum);
      expect(
        (await database.rawQuery(
          'SELECT typeof(balance) AS type FROM viewer_balances',
        )).single['type'],
        'integer',
      );
      expect(await balances.debit('viewer', maximum), 0);
      expect(() => balances.credit('viewer', -1), throwsRangeError);
      expect(() => balances.debit('viewer', -1), throwsRangeError);
      expect(() => balances.credit('', 1), throwsArgumentError);
      expect(() => balances.credit(' viewer ', 1), throwsArgumentError);
    },
  );

  test('schema rejects fractional and negative balances', () async {
    await balances.credit('viewer', 5);
    for (final value in [-1, 1.5]) {
      await expectLater(
        database.update('viewer_balances', {'balance': value}),
        throwsA(isA<DatabaseException>()),
      );
    }
    expect(await balances.balanceOf('viewer'), 5);
  });

  test(
    'names are nonunique, parameterized and refreshed by both mutations',
    () async {
      const name = "Same'; DROP TABLE viewer_balances; --";
      for (final id in ['one', 'two']) {
        await balances.credit(id, 10, username: 'same', displayName: name);
      }
      expect(
        await database.query(
          'viewer_balances',
          where: 'username = ?',
          whereArgs: ['SAME'],
        ),
        hasLength(2),
      );
      await balances.credit(
        'one',
        2,
        username: 'renamed',
        displayName: 'New Name',
      );
      await balances.debit(
        'one',
        1,
        username: 'latest',
        displayName: 'Latest Name',
      );
      final row = (await database.query(
        'viewer_balances',
        where: 'viewer_id = ?',
        whereArgs: ['one'],
      )).single;
      expect(row, {
        'viewer_id': 'one',
        'username': 'latest',
        'display_name': 'Latest Name',
        'balance': 11,
      });
      await expectLater(
        balances.debit('one', 12, username: 'failed', displayName: 'Failed'),
        throwsStateError,
      );
      await balances.credit('one', 1);
      final after = (await database.query(
        'viewer_balances',
        where: 'viewer_id = ?',
        whereArgs: ['one'],
      )).single;
      expect(after['username'], 'latest');
      expect(after['display_name'], 'Latest Name');
      expect(after['balance'], 12);
    },
  );

  test('overflow rolls back names along with the balance', () async {
    await balances.credit(
      'viewer',
      ViewerBalancesStore.maxBalance,
      username: 'original',
      displayName: 'Original',
    );
    await expectLater(
      balances.credit('viewer', 1, username: 'changed', displayName: 'Changed'),
      throwsStateError,
    );
    final row = (await database.query('viewer_balances')).single;
    expect(row['username'], 'original');
    expect(row['display_name'], 'Original');
    expect(row['balance'], ViewerBalancesStore.maxBalance);
  });

  test('upgrades v1 without losing rewards and persists balances across saves and reopen', () async {
    final directory = await Directory.systemTemp.createTemp('listener-points-');
    final databasePath = '${directory.path}${Platform.pathSeparator}rewards.db';
    addTearDown(() async {
      await databaseFactoryFfi.deleteDatabase(databasePath);
      await directory.delete();
    });
    final oldDatabase = await databaseFactoryFfi.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE rewards (position INTEGER PRIMARY KEY, payload TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
          );
          await db.insert('rewards', {
            'position': 0,
            'payload': '{"name":"Existing","handlers":[]}',
          });
          await db.insert('metadata', {
            'key': 'shared_preferences_imported',
            'value': '1',
          });
        },
      ),
    );
    await oldDatabase.close();
    final store = await RewardsStore.open(
      factory: databaseFactoryFfi,
      databasePath: databasePath,
    );
    expect((await store.loadAndMigrate(null)).rewards.single.name, 'Existing');
    await store.viewerBalances.credit(
      'viewer',
      123,
      username: 'login',
      displayName: 'Display Name',
    );
    await store.save(Rewards(rewards: []));
    await store.close();
    final reopened = await RewardsStore.open(
      factory: databaseFactoryFfi,
      databasePath: databasePath,
    );
    addTearDown(reopened.close);
    expect(await reopened.viewerBalances.balanceOf('viewer'), 123);
    expect((await reopened.load()).rewards, isEmpty);
    final connection = await databaseFactoryFfi.openDatabase(databasePath);
    final row = (await connection.query('viewer_balances')).single;
    expect(row['username'], 'login');
    expect(row['display_name'], 'Display Name');
  });

  test(
    'creates schema v2 once and preserves its data when reopening',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'listener-schema-v2-',
      );
      final databasePath =
          '${directory.path}${Platform.pathSeparator}rewards.db';
      addTearDown(() async {
        await databaseFactoryFfi.deleteDatabase(databasePath);
        await directory.delete();
      });
      final created = await RewardsStore.open(
        factory: databaseFactoryFfi,
        databasePath: databasePath,
      );
      await created.loadAndMigrate(null);
      await created.save(
        Rewards(
          rewards: [Reward(name: 'Existing reward', handlers: [])],
        ),
      );
      await created.viewerBalances.credit(
        'existing-viewer',
        125,
        username: 'existing_login',
        displayName: 'Existing Viewer',
      );
      await created.close();

      final reopened = await RewardsStore.open(
        factory: databaseFactoryFfi,
        databasePath: databasePath,
      );
      addTearDown(reopened.close);
      expect(
        (await reopened.loadAndMigrate(null)).rewards.single.name,
        'Existing reward',
      );
      final viewer = (await reopened.viewerBalances.loadBalances()).single;
      expect(viewer.viewerId, 'existing-viewer');
      expect(viewer.username, 'existing_login');
      expect(viewer.displayName, 'Existing Viewer');
      expect(viewer.balance, 125);
      expect(await reopened.viewerBalances.credit('existing-viewer', 5), 130);
      final connection = await databaseFactoryFfi.openDatabase(databasePath);
      expect(await connection.getVersion(), 2);
    },
  );
}

Future<bool> _attempt(Future<int> operation) async {
  try {
    await operation;
    return true;
  } on StateError {
    return false;
  }
}
