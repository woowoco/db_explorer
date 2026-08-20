import 'package:db_explorer_app/core/utils/app_logger.dart';
import 'package:db_explorer_app/domain/database/connection.dart';
import 'package:db_explorer_app/domain/database/database_provider.dart';
import 'package:db_explorer_app/domain/database/schema.dart';
import 'package:db_explorer_app/infrastructure/storage/local_cache.dart';

/// Schema discovery with cache layer.
///
/// Strategy:
/// 1. Check LocalCache (TTL 5min)
/// 2. Cache miss/expired → call provider.listCollections()
/// 3. Cache result
///
/// Write mutation sonrasında [invalidateForDatabase] çağrılmalı.
class SchemaService {
  SchemaService({required this.cache, required this.providerFactory});

  final LocalCache cache;

  /// Provider factory — listCollections() için.
  final DatabaseProviderFactory providerFactory;

  final _log = getLogger('SchemaService');

  /// Database list al (cache yok — admin/config/local her zaman değişebilir).
  Future<List<DatabaseNode>> listDatabases(DatabaseConnection connection) {
    final provider = providerFactory.create();
    return provider.listDatabases(connection);
  }

  /// Collection list al (cache hit → direkt, miss → provider).
  Future<List<CollectionNode>> listCollections(
    DatabaseConnection connection,
    String database,
  ) async {
    final cached = await cache.getCachedSchema(connection.profile.id, database);
    if (cached != null) {
      _log.d('Schema cache HIT: $database');
      return cached;
    }

    _log.d('Schema cache MISS: $database — fetching from provider');
    final provider = providerFactory.create();
    final fresh = await provider.listCollections(connection, database);
    await cache.cacheSchema(connection.profile.id, database, fresh);
    return fresh;
  }

  /// Write mutation sonrası invalidate.
  Future<void> invalidateForDatabase(
    String connectionId,
    String database,
  ) async {
    await cache.invalidateSchema(connectionId, database);
  }

  /// Tüm schema cache'i temizle (settings action).
  Future<void> clearAll() async {
    await cache.clearSchemaCache();
  }
}