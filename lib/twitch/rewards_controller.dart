import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:twitch_listener/autosaver.dart';
import 'package:twitch_listener/settings.dart';
import 'package:twitch_listener/twitch/dto.dart';
import 'package:twitch_listener/twitch/reward_settings.dart';
import 'package:twitch_listener/twitch/twitch_api.dart';
import 'package:twitch_listener/twitch/twitch_creds.dart';
import 'package:twitch_listener/twitch_shared.dart';

enum TwitchRewardsError {
  notConnected,
  authorization,
  forbidden,
  notFound,
  invalid,
  rateLimited,
  network,
  accountChanged,
  unknown,
}

class TwitchRewardsException implements Exception {
  final TwitchRewardsError kind;
  const TwitchRewardsException(this.kind);
}

class TwitchRewardSelection {
  final RedemptionDto reward;
  final String broadcasterId;
  const TwitchRewardSelection(this.reward, this.broadcasterId);
}

/// Owns reward discovery, Twitch's management permissions, and channel identity.
/// Local reaction chains remain independent of remote reward mutations.
class TwitchRewardsController extends ChangeNotifier {
  final Settings settings;
  final TwitchShared shared;
  final Autosaver autosaver;
  final TwitchApi Function(TwitchCreds credentials) createApi;
  final Future<TwitchCreds?> Function() authorize;
  late final StreamSubscription<TwitchCreds?> _authSubscription;
  String? _account;
  int _generation = 0;
  int _revision = 0;
  bool _disposed = false;
  Future<void>? _refreshing;

  bool loading = false;
  bool saving = false;
  bool authorizing = false;
  bool canManage = false;
  bool manageabilityKnown = false;
  bool permissionError = false;
  TwitchRewardsError? error;
  Set<String> _manageableIds = {};

  TwitchRewardsController({
    required this.settings,
    required this.shared,
    required this.autosaver,
    required this.createApi,
    required this.authorize,
  }) {
    _account = accountKey;
    _authSubscription = settings.twitchAuthChanges.listen((_) {
      if (_account == accountKey) {
        return; // Token refresh keeps channel identity.
      }
      _account = accountKey;
      _generation++;
      _revision++;
      _refreshing = null;
      loading = saving = false;
      canManage = manageabilityKnown = permissionError = false;
      _manageableIds = {};
      error = null;
      shared.clear();
      _notify();
    });
  }

  String? get accountKey {
    final auth = settings.twitchAuth;
    return auth == null ? null : '${auth.clientId}:${auth.broadcasterId}';
  }

  bool get connected => settings.twitchAuth != null;
  List<RedemptionDto> get rewards => shared.redemptions.current.values.toList();
  bool isManageable(String id) =>
      manageabilityKnown && _manageableIds.contains(id);
  bool canEdit(String id) => canManage && isManageable(id);

  Future<void> refresh() {
    if (_disposed || saving) return Future.value();
    final pending = _refreshing;
    if (pending != null) return pending;
    final auth = settings.twitchAuth;
    if (auth == null) {
      error = TwitchRewardsError.notConnected;
      _notify();
      return Future.value();
    }
    final generation = _generation;
    final revision = _revision;
    loading = true;
    error = null;
    _notify();
    final future = _load(createApi(auth), auth, generation, revision);
    _refreshing = future;
    return future;
  }

  Future<void> _load(
    TwitchApi api,
    TwitchCreds auth,
    int generation,
    int revision,
  ) async {
    try {
      final all = await api.getCustomRewards();
      Set<String> manageable = {};
      Set<String> scopes = {};
      var known = false;
      var failed = false;
      try {
        manageable = (await api.getCustomRewards(onlyManageable: true))
            .map((reward) => reward.id)
            .toSet();
        known = true;
        scopes = await api.getGrantedScopes();
      } catch (_) {
        failed = true;
      }
      if (!_active(generation) || revision != _revision) return;
      _manageableIds = manageable;
      manageabilityKnown = known;
      canManage = scopes.contains('channel:manage:redemptions');
      permissionError = failed;
      _synchronizeNames(all, auth.broadcasterId);
      shared.setRewards(all, broadcasterId: auth.broadcasterId);
    } catch (exception) {
      if (_active(generation) && revision == _revision) {
        error = classifyError(exception);
      }
    } finally {
      api.close();
      if (_active(generation)) {
        loading = false;
        _refreshing = null;
        _notify();
      }
    }
  }

  void _synchronizeNames(
    Iterable<RedemptionDto> rewards,
    String broadcasterId,
  ) {
    final byId = {for (final reward in rewards) reward.id: reward};
    var changed = false;
    for (final local in settings.rewards.rewards) {
      if (!local.isLinked || local.twitchBroadcasterId != broadcasterId) {
        continue;
      }
      final remote = byId[local.twitchRewardId];
      if (remote != null && local.name != remote.title) {
        local.name = remote.title;
        changed = true;
      }
    }
    if (changed) autosaver.notifyChanges();
  }

  TwitchRewardSelection select(String id) {
    final auth = settings.twitchAuth;
    if (auth == null || shared.broadcasterId != auth.broadcasterId) {
      throw const TwitchRewardsException(TwitchRewardsError.accountChanged);
    }
    final remote = rewards.where((reward) => reward.id == id).firstOrNull;
    if (remote == null) {
      throw const TwitchRewardsException(TwitchRewardsError.notFound);
    }
    return TwitchRewardSelection(remote, auth.broadcasterId);
  }

  Future<RedemptionDto> saveReward(
    TwitchRewardSettings value, {
    String? id,
    required String? expectedAccount,
  }) async {
    final auth = settings.twitchAuth;
    if (expectedAccount != accountKey || auth == null) {
      throw const TwitchRewardsException(TwitchRewardsError.accountChanged);
    }
    if (!canManage) {
      throw const TwitchRewardsException(TwitchRewardsError.authorization);
    }
    if (id != null && !canEdit(id)) {
      throw const TwitchRewardsException(TwitchRewardsError.forbidden);
    }
    if (saving) throw const TwitchRewardsException(TwitchRewardsError.unknown);
    final generation = _generation;
    final api = createApi(auth);
    saving = true;
    _revision++; // An older refresh cannot overwrite a successful edit.
    _notify();
    try {
      final result = id == null
          ? await api.createCustomReward(value)
          : await api.updateCustomReward(id, value);
      if (!_active(generation)) {
        throw const TwitchRewardsException(TwitchRewardsError.accountChanged);
      }
      _revision++;
      _manageableIds.add(result.id);
      final updated = [
        ...rewards.where((reward) => reward.id != result.id),
        result,
      ];
      _synchronizeNames(updated, auth.broadcasterId);
      shared.setRewards(updated, broadcasterId: auth.broadcasterId);
      return result;
    } catch (exception) {
      final kind = classifyError(exception);
      if (_active(generation)) {
        if (kind == TwitchRewardsError.authorization) canManage = false;
        if (kind == TwitchRewardsError.forbidden && id != null) {
          _manageableIds.remove(id);
        }
        if (kind == TwitchRewardsError.notFound && id != null) {
          _manageableIds.remove(id);
          shared.setRewards(
            rewards.where((reward) => reward.id != id),
            broadcasterId: auth.broadcasterId,
          );
        }
      }
      throw TwitchRewardsException(kind);
    } finally {
      api.close();
      if (_active(generation)) {
        saving = false;
        _notify();
      }
    }
  }

  Future<void> connect() async {
    if (authorizing) return;
    authorizing = true;
    error = null;
    _notify();
    try {
      final credentials = await authorize();
      if (_disposed || credentials == null) return;
      await settings.saveTwitchAuth(credentials);
      // Allow the auth stream to invalidate the old channel before loading.
      await Future<void>.delayed(Duration.zero);
      await refresh();
    } catch (exception) {
      if (!_disposed) error = classifyError(exception);
    } finally {
      if (!_disposed) {
        authorizing = false;
        _notify();
      }
    }
  }

  bool _active(int generation) =>
      !_disposed && generation == _generation && _account == accountKey;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  static TwitchRewardsError classifyError(Object exception) {
    if (exception is TwitchRewardsException) return exception.kind;
    if (exception is DioException) {
      return switch (exception.response?.statusCode) {
        400 => TwitchRewardsError.invalid,
        401 => TwitchRewardsError.authorization,
        403 => TwitchRewardsError.forbidden,
        404 => TwitchRewardsError.notFound,
        429 => TwitchRewardsError.rateLimited,
        null => TwitchRewardsError.network,
        _ => TwitchRewardsError.unknown,
      };
    }
    return TwitchRewardsError.unknown;
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _authSubscription.cancel();
    super.dispose();
  }
}
