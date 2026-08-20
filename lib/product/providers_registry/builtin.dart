import 'package:db_explorer_app/domain/database/connection.dart';
import 'package:db_explorer_app/infrastructure/ai_providers/disabled.dart';
import 'package:db_explorer_app/infrastructure/ai_providers/local_llamacpp.dart';
import 'package:db_explorer_app/infrastructure/ai_providers/ollama_remote.dart';
import 'package:db_explorer_app/infrastructure/ai_providers/openai_compatible.dart';
import 'package:db_explorer_app/infrastructure/database_providers/elasticsearch/elasticsearch_provider.dart';
import 'package:db_explorer_app/infrastructure/database_providers/mongodb/mongodb_provider.dart';
import 'package:db_explorer_app/infrastructure/database_providers/postgres/postgres_provider.dart';
import 'package:db_explorer_app/infrastructure/database_providers/redis/redis_provider.dart';
import 'package:db_explorer_app/infrastructure/registry/ai_provider_registry.dart';
import 'package:db_explorer_app/infrastructure/registry/database_provider_registry.dart';

/// Built-in provider factory registrations.
///
/// Varsayılan: MongoDB + PostgreSQL + Redis + Elasticsearch provider
/// factory'leri (Phase 1/5/6 mock — geliştirme/test için in-memory seed data).
///
/// **Production binding**: Gerçek `mongo_dart`, `postgres`, `redis`,
/// `elastic_client` driver kullanan `Real*ProviderFactory` sınıfları
/// AppBootstrap'ta feature flag ile mock'ların yerini alır:
/// - `settings.useRealMongoDriver` → `RealMongoDBProviderFactory`
/// - `settings.useRealPostgresDriver` → `RealPostgresProviderFactory`
/// - `settings.useRealRedisDriver` → `RealRedisProviderFactory`
/// - `settings.useRealElasticsearchDriver` → `RealElasticsearchProviderFactory`
///
/// Phase 8 release prep'te wiring tamamlanacak.
///
/// NOT: Registry `Map<DatabaseKind, ...>` olduğu için aynı kind için
/// iki factory kaydedilirse sonuncusu kazanır (mock → real override).
void registerBuiltinProviders() {
  _registerDatabase();
  _registerAi();
}

/// Database provider factory kayıtları.
///
/// Phase 6 sonunda 4 kind için hem mock hem real factory tanımlı;
/// mock default kalır (Phase 8 release prep'te real wiring tamamlanacak).
void _registerDatabase() {
  final dbRegistry = DatabaseProviderRegistry.instance;

  // MongoDB: mock default, real override hazır.
  if (!dbRegistry.isRegistered(DatabaseKind.mongodb)) {
    dbRegistry.register(const MongoDBProviderFactory());
  }

  // PostgreSQL (Phase 5): mock default, real override hazır.
  if (!dbRegistry.isRegistered(DatabaseKind.postgres)) {
    dbRegistry.register(const PostgresDBProviderFactory());
  }

  // Redis (Phase 6): mock default, real override hazır.
  if (!dbRegistry.isRegistered(DatabaseKind.redis)) {
    dbRegistry.register(const RedisDBProviderFactory());
  }

  // Elasticsearch (Phase 6): mock default, real override hazır.
  if (!dbRegistry.isRegistered(DatabaseKind.elasticsearch)) {
    dbRegistry.register(const ElasticsearchDBProviderFactory());
  }
}

/// AI provider factory kayıtları.
void _registerAi() {
  final aiRegistry = AiProviderRegistry.instance;
  aiRegistry.register(const DisabledProvider()); // default — AI kapalı
  aiRegistry.register(LocalLlamaCppProvider()); // Phase 7+
  aiRegistry.register(OllamaRemoteProvider()); // Phase 7+
  aiRegistry.register(OpenAiCompatibleProvider()); // Phase 7+
}
