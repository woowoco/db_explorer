import 'dart:convert';

import 'package:db_explorer_app/domain/database/connection.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Connection profile'lar için secure storage wrapper.
///
/// macOS 2026 key-name bug workaround: key'ler `dbx_conn_<uuid>` prefix
/// ile saklanır; `_` ve `-` dışında özel karakter kullanılmaz.
class SecureConnectionStore {
  SecureConnectionStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static String _key(String id) => 'dbx_conn_$id';

  /// Connection profile'ı secure storage'a yaz.
  Future<void> save(DatabaseConnectionConfig profile) async {
    final json = jsonEncode(_profileToJson(profile));
    await _storage.write(key: _key(profile.id), value: json);
  }

  /// ID ile connection profile oku.
  Future<DatabaseConnectionConfig?> load(String id) async {
    final raw = await _storage.read(key: _key(id));
    if (raw == null) return null;
    return _profileFromJson(jsonDecode(raw) as Map<String, Object?>);
  }

  /// Connection profile sil.
  Future<void> delete(String id) async {
    await _storage.delete(key: _key(id));
  }

  /// Saklanan tüm connection ID'lerini listele.
  ///
  /// Not: secure storage'da "list keys" API yok; bu implementasyon
  /// ayrı bir SharedPreferences index kullanır. Phase 0'da boş liste
  /// döndürür; Phase 2'de index eklenecek.
  Future<List<String>> listIds() async {
    return const [];
  }

  /// Smoke test: yazma / okuma çalışıyor mu?
  Future<bool> ping() async {
    try {
      const testKey = 'dbx_smoke_test';
      await _storage.write(key: testKey, value: 'ok');
      final read = await _storage.read(key: testKey);
      await _storage.delete(key: testKey);
      return read == 'ok';
    } catch (_) {
      return false;
    }
  }

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
      ),
      _ => throw ArgumentError('Unknown profile kind: $kind'),
    };
  }
}
