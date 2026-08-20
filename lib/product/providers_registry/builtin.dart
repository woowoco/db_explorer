import 'package:db_explorer_app/domain/database/connection.dart';
import 'package:db_explorer_app/infrastructure/ai_providers/disabled.dart';
import 'package:db_explorer_app/infrastructure/database_providers/elasticsearch/elasticsearch_provider.dart';
import 'package:db_explorer_app/infrastructure/database_providers/mongodb/mongodb_provider.dart';
import 'package:db_explorer_app/infrastructure/database_providers/postgres/postgres_provider.dart';
import 'package:db_explorer_app/infrastructure/database_providers/redis/redis_provider.dart';
import 'package:db_explorer_app/infrastructure/registry/ai_provider_registry.dart';
import 'package:db_explorer_app/infrastructure/registry/database_provider_registry.dart';
import 'package:db_explorer_app/infrastructure/storage/settings.dart';
import 'package:db_explorer_app/product/providers_registry/real_ai_factories.dart';

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
/// **AI binding (Phase 8)**: `AppSettings.aiMode` değerine göre
/// `RealAiProviderFactory` üzerinden tek bir provider seçilir ve
/// `DisabledProvider` her zaman fallback olarak register edilir.
///
/// NOT: Registry `Map<DatabaseKind, ...>` olduğu için aynı kind için
/// iki factory kaydedilirse sonuncusu kazanır (mock → real override).
/// AI registry'si sıralı liste; ilk available provider kullanılır.
void registerBuiltinProviders(AppSettings settings) {
  _registerDatabase();
  _registerAi(settings);
  // Sensitive pattern'leri AiPromptBuilder'a push et (bir kez, app boot'ta).
  // Kullanıcı Settings'i değiştirirse `applySensitiveFieldPatterns()`
  // tekrar çağrılabilir (manual re-apply için).
  applySensitiveFieldPatterns(settings);
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

/// AI provider factory kayıtları (Phase 8 — Settings-driven).
///
/// `AppSettings.aiMode`:
/// - `local` → `RealAiProviderFactory.buildLocalLlamaCpp()`
/// - `ollamaRemote` → `RealAiProviderFactory.buildOllamaRemote()`
/// - `openaiCompatible` → `RealAiProviderFactory.buildOpenAiCompatible()`
/// - `disabled` (default) → yalnızca `DisabledProvider`
///
/// `DisabledProvider` her zaman fallback olarak register edilir — bu
/// sayede kullanıcı bir mode seçmemişse bile registry boş değildir ve
/// `defaultProvider()` her zaman bir sonuç döner.
void _registerAi(AppSettings settings) {
  final aiRegistry = AiProviderRegistry.instance;
  aiRegistry.clear();

  // Fallback — her zaman register (default available provider).
  aiRegistry.register(const DisabledProvider());

  // Kullanıcı seçimine göre aktif provider.
  final selected = RealAiProviderFactory(settings).buildFromSettings();
  if (selected != null) {
    aiRegistry.register(selected);
  }
}
