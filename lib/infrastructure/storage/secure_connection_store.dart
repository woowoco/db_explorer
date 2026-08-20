import 'dart:convert';

import 'package:db_explorer_app/core/utils/app_error.dart';
import 'package:db_explorer_app/core/utils/app_logger.dart';
import 'package:db_explorer_app/domain/database/connection.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Connection profile'lar için secure storage wrapper.
///
/// macOS 2026 key-name bug workaround: key'ler `dbx_conn_<uuid>` prefix
/// ile saklanır; `_` ve `-` dışında özel karakter kullanılmaz.
///
/// Phase 2'de:
/// - Tüm MongoConnectionProfile alanları (Phase 1'de eklenen ssl,
///   replicaSet, directConnection, serverSelectionTimeoutMs) JSON'da.
/// - listIds() artık SharedPreferences index kullanır (`dbx_conn_index`).
/// - Corrupt JSON → StorageFailure (load null yerine exception fırlatır).
class SecureConnectionStore {
  SecureConnectionStore({
    FlutterSecureStorage? storage,
    SharedPreferences? sharedPrefs,
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _prefs = sharedPrefs;

  final FlutterSecureStorage _storage;
  SharedPreferences? _prefs;

  final _log = getLogger('SecureConnStore');

  static const _keyPrefix = 'dbx_conn_';
  static const _indexKey = 'dbx_conn_index';
  static const _smokeTestKey = 'dbx_smoke_test';

  static String _key(String id) => '$_keyPrefix$id';

  /// SharedPreferences lazy initialize.
  Future<SharedPreferences> _getPrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  /// Connection profile'ı secure storage'a yaz + index güncelle.
  Future<void> save(DatabaseConnectionConfig profile) async {
    final json = jsonEncode(_profileToJson(profile));
    await _storage.write(key: _key(profile.id), value: json);
    await _addToIndex(profile.id);
    _log.d('Saved connection: ${profile.label} (${profile.id})');
  }

  /// ID ile connection profile oku.
  ///
  /// Bulunamazsa null; corrupt JSON durumunda StorageFailure.
  Future<DatabaseConnectionConfig?> load(String id) async {
    final raw = await _storage.read(key: _key(id));
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, Object?>;
      return _profileFromJson(json);
    } on FormatException catch (e) {
      throw StorageFailure(
        'Corrupt connection profile JSON for id=$id',
        cause: e,
      );
    } on TypeError catch (e) {
      throw StorageFailure(
        'Invalid connection profile shape for id=$id',
        cause: e,
      );
    }
  }

  /// Connection profile sil + index'ten çıkar.
  Future<void> delete(String id) async {
    await _storage.delete(key: _key(id));
    await _removeFromIndex(id);
    _log.d('Deleted connection: $id');
  }

  /// Saklanan tüm connection ID'lerini listele (index'ten).
  Future<List<String>> listIds() async {
    final prefs = await _getPrefs();
    final ids = prefs.getStringList(_indexKey) ?? const [];
    return List<String>.unmodifiable(ids);
  }

  /// Tüm connection profile'ları yükle (load N kere).
  ///
  /// Corrupt profile → o entry skip edilir (warning log).
  Future<List<DatabaseConnectionConfig>> loadAll() async {
    final ids = await listIds();
    final profiles = <DatabaseConnectionConfig>[];
    for (final id in ids) {
      try {
        final p = await load(id);
        if (p != null) profiles.add(p);
      } on StorageFailure catch (e) {
        _log.w('Skipping corrupt profile $id: ${e.message}');
      }
    }
    return profiles;
  }

  /// Smoke test: yazma / okuma çalışıyor mu?
  Future<bool> ping() async {
    try {
      await _storage.write(key: _smokeTestKey, value: 'ok');
      final read = await _storage.read(key: _smokeTestKey);
      await _storage.delete(key: _smokeTestKey);
      return read == 'ok';
    } catch (_) {
      return false;
    }
  }

  // ─── Internal: index management ───────────────────────────────────
  Future<void> _addToIndex(String id) async {
    final prefs = await _getPrefs();
    final ids = List<String>.from(prefs.getStringList(_indexKey) ?? []);
    if (!ids.contains(id)) {
      ids.add(id);
      await prefs.setStringList(_indexKey, ids);
    }
  }

  Future<void> _removeFromIndex(String id) async {
    final prefs = await _getPrefs();
    final ids = List<String>.from(prefs.getStringList(_indexKey) ?? []);
    if (ids.remove(id)) {
      await prefs.setStringList(_indexKey, ids);
    }
  }

  // ─── Internal: JSON (de)serialization ─────────────────────────────
  Map<String, Object?> _profileToJson(DatabaseConnectionConfig profile) {
    return switch (profile) {
      MongoConnectionProfile() => {
        'kind': 'mongodb',
        'id': profile.id,
        'label': profile.label,
        'host': profile.host,
        'port': profile.port,
        'databaseName': profile.databaseName,
        'username': profile.username,
        'options': profile.options,
        'password': profile.password,
        'authSource': profile.authSource,
        'replicaSet': profile.replicaSet,
        'ssl': profile.ssl,
        'directConnection': profile.directConnection,
        'serverSelectionTimeoutMs': profile.serverSelectionTimeoutMs,
      },
    };
  }

  DatabaseConnectionConfig _profileFromJson(Map<String, Object?> json) {
    final kind = json['kind'] as String;
    return switch (kind) {
      'mongodb' => MongoConnectionProfile(
        id: json['id'] as String,
        label: json['label'] as String,
        host: json['host'] as String,
        port: json['port'] as int,
        databaseName: json['databaseName'] as String?,
        username: json['username'] as String?,
        options: (json['options'] as Map?)?.cast<String, String>() ?? const {},
        password: json['password'] as String?,
        authSource: json['authSource'] as String?,
        replicaSet: json['replicaSet'] as String?,
        ssl: (json['ssl'] as bool?) ?? false,
        directConnection: (json['directConnection'] as bool?) ?? false,
        serverSelectionTimeoutMs: json['serverSelectionTimeoutMs'] as int?,
      ),
      _ => throw ArgumentError('Unknown profile kind: $kind'),
    };
  }
}