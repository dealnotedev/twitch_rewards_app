import 'dart:async';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:twitch_listener/points/viewer_balance.dart';

/// Integer balances keyed by immutable Twitch user IDs, shared by all chains.
class ViewerBalancesStore {
  ViewerBalancesStore(this._database);

  static const maxBalance = 0x7fffffffffffffff;
  final Database _database;
  final _changes = StreamController<void>.broadcast();

  Stream<void> get changes => _changes.stream;

  Future<List<ViewerBalance>> loadBalances() async {
    final rows = await _database.query(
      'viewer_balances',
      orderBy: 'balance DESC, username ASC, viewer_id ASC',
    );
    return rows.map(ViewerBalance.fromRow).toList();
  }

  int _balanceChanged(int balance) {
    _changes.add(null);
    return balance;
  }

  void dispose() => _changes.close();

  static Future<void> createTable(DatabaseExecutor database) async {
    await database.execute('''
        CREATE TABLE viewer_balances (
          viewer_id TEXT NOT NULL PRIMARY KEY CHECK(length(trim(viewer_id)) > 0),
          username TEXT NOT NULL DEFAULT '' COLLATE NOCASE,
          display_name TEXT NOT NULL DEFAULT '' COLLATE NOCASE,
          balance INTEGER NOT NULL DEFAULT 0
            CHECK(typeof(balance) = 'integer' AND balance >= 0)
        )
      ''');
    await database.execute(
      'CREATE INDEX viewer_balances_username ON viewer_balances (username)',
    );
    await database.execute(
      'CREATE INDEX viewer_balances_display_name ON viewer_balances (display_name)',
    );
  }

  Future<int> balanceOf(String viewerId) async {
    _validateViewer(viewerId);
    return _readBalance(_database, viewerId);
  }

  /// The row creation, guarded increment and result are one transaction.
  /// Check the available headroom before arithmetic: SQLite otherwise promotes
  /// overflowing INTEGER additions to REAL and loses precision.
  Future<int> credit(
    String viewerId,
    int amount, {
    String? username,
    String? displayName,
  }) {
    _validate(viewerId, amount);
    return _database
        .transaction((transaction) async {
          await transaction.rawInsert(
            'INSERT INTO viewer_balances (viewer_id, balance) VALUES (?, 0) '
            'ON CONFLICT(viewer_id) DO NOTHING',
            [viewerId],
          );
          final changed = await transaction.rawUpdate(
            'UPDATE viewer_balances SET balance = balance + ?, '
            'username = COALESCE(?, username), '
            'display_name = COALESCE(?, display_name) '
            'WHERE viewer_id = ? AND balance <= ?',
            [amount, username, displayName, viewerId, maxBalance - amount],
          );
          if (changed != 1) throw StateError('Viewer balance limit exceeded');
          return _readBalance(transaction, viewerId);
        })
        .then(_balanceChanged);
  }

  /// An insufficient balance fails without changing or creating a viewer row.
  Future<int> debit(
    String viewerId,
    int amount, {
    String? username,
    String? displayName,
  }) {
    _validate(viewerId, amount);
    return _database
        .transaction((transaction) async {
          final changed = await transaction.rawUpdate(
            'UPDATE viewer_balances SET balance = balance - ?, '
            'username = COALESCE(?, username), '
            'display_name = COALESCE(?, display_name) '
            'WHERE viewer_id = ? AND balance >= ?',
            [amount, username, displayName, viewerId, amount],
          );
          if (changed != 1) throw StateError('Insufficient viewer points');
          return _readBalance(transaction, viewerId);
        })
        .then(_balanceChanged);
  }

  static Future<int> _readBalance(
    DatabaseExecutor database,
    String viewerId,
  ) async {
    final rows = await database.query(
      'viewer_balances',
      columns: ['balance'],
      where: 'viewer_id = ?',
      whereArgs: [viewerId],
      limit: 1,
    );
    return rows.isEmpty ? 0 : rows.single['balance'] as int;
  }

  static void _validateViewer(String viewerId) {
    if (viewerId.isEmpty || viewerId != viewerId.trim()) {
      throw ArgumentError.value(
        viewerId,
        'viewerId',
        'A Twitch ID is required',
      );
    }
  }

  static void _validate(String viewerId, int amount) {
    _validateViewer(viewerId);
    if (amount < 0 || amount > maxBalance) {
      throw RangeError.range(amount, 0, maxBalance, 'amount');
    }
  }
}
