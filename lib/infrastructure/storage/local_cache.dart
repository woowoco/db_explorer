import 'package:db_explorer_app/core/utils/app_error.dart';
import 'package:db_explorer_app/core/utils/app_logger.dart';
import 'package:db_explorer_app/domain/database/schema.dart';
import 'package:db_explorer_app/infrastructure/database_providers/mongodb/mongodb_schema.dart';
import 'package:db_explorer_app/infrastructure/storage/query_history_entry.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';

/// Local cache — Hive encrypted box wrapper.
///
/// Encryption:
/// - AES-GCM 256-bit key Hive `HiveCipher` için.
/// - Key `flutter_secure_storage`'da saklanır (Keychain/KeyStore/DPAPI/libsecret).
///
/// Boxes (Phase 2):
/// - `schema_cache` — per-connection-per-database schema snapshot, TTL 5min
/// - `query_history` — kullanıcının çalıştırdığı sorgular, TTL configurable
///
/// Veri Hive Map olarak saklanır (TypeAdapter gerektirmez; Hive Map'i
/// primitive types ile destekler).
class LocalCache {
  /// Production constructor: secure storage kullanır.
  LocalCache({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
      _testKey = null;

  /// Test constructor: sabit key (secure storage'a dokunmaz).
  LocalCache.forTesting({required List<int> cipherKey})
    : _secureStorage = null,
      _testKey = cipherKey;

  final FlutterSecureStorage? _secureStorage;
  final List<int>? _testKey;

  static const _cacheKeyKey = 'dbx_hive_cache_key';
  static const _schemaBoxName = 'schema_cache';
  static const _historyBoxName = 'query_history';

  /// Schema cache TTL: 5 dakika.
  static const schemaCacheTtl = Duration(minutes: 5);

  /// Default history TTL: 30 gün.
  static const defaultHistoryTtlDays = 30;

  final _log = getLogger('LocalCache');

  bool _initialized = false;

  // ─── Lifecycle ────────────────────────────────────────────────────
  /// Hive'ı başlat + cipher'ı resolve et + box'ları aç.
  ///
  /// AppBootstrap tarafından fullInitialize'da çağrılır.
  Future<void> initialize() async {
    if (_initialized) return;
    if (!Hive.isAdapterRegistered(0)) {
      // Placeholder for future TypeAdapters — Map-based serialization
      // yeterli olduğu için şu an gerek yok.
    }
    _initialized = true;
    _log.i('LocalCache initialized');
  }

  /// Tüm box'ları kapat (shutdown sırasında).
  Future<void> closeAll() async {
    await Hive.close();
    _initialized = false;
  }

  // ─── Schema cache ────────────────────────────────────────────────
  Future<Box<dynamic>> _schemaBox() async {
    if (Hive.isBoxOpen(_schemaBoxName)) {
      return Hive.box<dynamic>(_schemaBoxName);
    }
    final cipher = await _resolveCipher();
    return Hive.openBox<dynamic>(_schemaBoxName, encryptionCipher: cipher);
  }

  /// Schema cache key: 'schema:`connectionId`:`database`'.
  static String schemaCacheKey(String connectionId, String database) =>
      'schema:$connectionId:$database';

  /// Schema snapshot al (cache hit).
  /// TTL aşılmışsa null.
  Future<List<CollectionNode>?> getCachedSchema(
    String connectionId,
    String database,
  ) async {
    final box = await _schemaBox();
    final key = schemaCacheKey(connectionId, database);
    final raw = box.get(key);
    if (raw == null) return null;

    final map = raw as Map<dynamic, dynamic>;
    final cachedAt = DateTime.fromMillisecondsSinceEpoch(
      map['cachedAt'] as int,
    );
    if (DateTime.now().difference(cachedAt) > schemaCacheTtl) {
      _log.d('Schema cache expired: $key');
      return null;
    }

    final list = (map['collections'] as List).cast<Map<dynamic, dynamic>>();
    return list.map<CollectionNode>((m) {
      final fields = (m['fields'] as List)
          .cast<Map<dynamic, dynamic>>()
          .map<FieldNode>((f) => MongoField(
                name: f['name'] as String,
                dataType: f['dataType'] as String,
                isNullable: (f['isNullable'] as bool?) ?? true,
                isIndexed: (f['isIndexed'] as bool?) ?? false,
              ))
          .toList();
      return MongoCollection(
        name: m['name'] as String,
        fields: fields,
        documentCount: m['documentCount'] as int?,
        averageDocumentSize: m['averageDocumentSize'] as int?,
      );
    }).toList();
  }

  /// Schema snapshot kaydet (TTL = schemaCacheTtl).
  Future<void> cacheSchema(
    String connectionId,
    String database,
    List<CollectionNode> collections,
  ) async {
    final box = await _schemaBox();
    final key = schemaCacheKey(connectionId, database);
    final map = {
      'cachedAt': DateTime.now().millisecondsSinceEpoch,
      'collections': collections
          .map< Map<String, Object?>>((c) => {
                'name': c.name,
                'documentCount': (c as MongoCollection?)?.documentCount,
                'averageDocumentSize':
                    (c as MongoCollection?)?.averageDocumentSize,
                'fields': c.fields
                    .map< Map<String, Object?>>((f) => {
                          'name': f.name,
                          'dataType': f.dataType,
                          'isNullable': f.isNullable,
                          'isIndexed': f.isIndexed,
                        })
                    .toList(),
              })
          .toList(),
    };
    await box.put(key, map);
    _log.d('Schema cached: $key (${collections.length} collections)');
  }

  /// Schema cache invalidate (write mutation sonrası).
  Future<void> invalidateSchema(String connectionId, String database) async {
    final box = await _schemaBox();
    final key = schemaCacheKey(connectionId, database);
    await box.delete(key);
    _log.d('Schema cache invalidated: $key');
  }

  /// Tüm schema cache'i temizle.
  Future<void> clearSchemaCache() async {
    final box = await _schemaBox();
    await box.clear();
    _log.i('Schema cache cleared');
  }

  // ─── Query history ───────────────────────────────────────────────
  Future<Box<dynamic>> _historyBox() async {
    if (Hive.isBoxOpen(_historyBoxName)) {
      return Hive.box<dynamic>(_historyBoxName);
    }
    final cipher = await _resolveCipher();
    return Hive.openBox<dynamic>(_historyBoxName, encryptionCipher: cipher);
  }

  /// Query history'ye entry ekle.
  Future<void> addHistoryEntry(QueryHistoryEntry entry) async {
    final box = await _historyBox();
    await box.put(entry.storageKey, entry.toMap());
    _log.d('History entry added: ${entry.id}');
  }

  /// Son N history entry (en yeni üstte).
  Future<List<QueryHistoryEntry>> getRecentHistory({int limit = 100}) async {
    final box = await _historyBox();
    final entries = box.values
        .map((e) => QueryHistoryEntry.fromMap(e as Map))
        .toList()
      ..sort((a, b) => b.executedAt.compareTo(a.executedAt));
    return entries.take(limit).toList();
  }

  /// Connection'a göre history filtrele.
  Future<List<QueryHistoryEntry>> getHistoryForConnection(
    String connectionId, {
    int limit = 100,
  }) async {
    final all = await getRecentHistory(limit: limit * 2);
    return all.where((e) => e.connectionId == connectionId).take(limit).toList();
  }

  /// TTL aşan history entry'leri sil.
  ///
  /// [ttlDays] settings'ten gelir (default 30 gün).
  Future<int> pruneHistory({required int ttlDays}) async {
    final box = await _historyBox();
    final cutoff = DateTime.now().subtract(Duration(days: ttlDays));
    final keysToDelete = <dynamic>[];

    for (final key in box.keys) {
      final raw = box.get(key);
      if (raw == null) continue;
      try {
        final entry = QueryHistoryEntry.fromMap(raw as Map);
        if (entry.executedAt.isBefore(cutoff)) {
          keysToDelete.add(key);
        }
      } on TypeError {
        // Corrupt entry → sil
        keysToDelete.add(key);
      }
    }

    if (keysToDelete.isNotEmpty) {
      await box.deleteAll(keysToDelete);
    }
    _log.i('Pruned $keysToDelete entries (older than $ttlDays days)');
    return keysToDelete.length;
  }

  /// Tüm history'i temizle.
  Future<void> clearHistory() async {
    final box = await _historyBox();
    await box.clear();
    _log.i('Query history cleared');
  }

  // ─── Internal: cipher ────────────────────────────────────────────
  Future<HiveCipher> _resolveCipher() async {
    // Test mode: sabit key ile çalış.
    final testKey = _testKey;
    if (testKey != null) {
      return HiveAesCipher(testKey);
    }
    final storage = _secureStorage;
    if (storage == null) {
      throw StorageFailure(
        'LocalCache not configured: no secureStorage or testKey',
      );
    }
    final existing = await storage.read(key: _cacheKeyKey);
    if (existing != null) {
      try {
        return HiveAesCipher(_decodeKey(existing));
      } on FormatException {
        throw StorageFailure(
          'Corrupt Hive cipher key in secure storage',
          cause: existing,
        );
      }
    }
    final newKey = Hive.generateSecureKey();
    await storage.write(key: _cacheKeyKey, value: _encodeKey(newKey));
    return HiveAesCipher(newKey);
  }

  String _encodeKey(List<int> key) {
    return key.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  List<int> _decodeKey(String hex) {
    final result = <int>[];
    for (var i = 0; i < hex.length; i += 2) {
      result.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return result;
  }
}