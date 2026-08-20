import 'package:db_explorer_app/domain/database/connection.dart';
import 'package:db_explorer_app/domain/database/database_provider.dart';
import 'package:db_explorer_app/infrastructure/registry/database_provider_registry.dart';
import 'package:db_explorer_app/infrastructure/storage/local_cache.dart';
import 'package:db_explorer_app/infrastructure/storage/schema_service.dart';
import 'package:get_it/get_it.dart';

/// GetIt modülü — database provider registry + schema service.
///
/// Built-in provider factory'ler `product/providers_registry/builtin.dart`
/// üzerinden kayıt edilir; burada registry singleton olarak expose edilir
/// + SchemaService (cache + provider wrapper) register edilir.
class DatabaseModule {
  DatabaseModule._();

  static void register(GetIt getIt) {
    // DatabaseProviderRegistry zaten singleton; burada sadece
    // erişim için bir delegate getIt'ye konur.
    getIt.registerSingleton<DatabaseProviderRegistry>(
      DatabaseProviderRegistry.instance,
    );

    // Default provider factory reference (UI için hangi tür seçili).
    if (!getIt.isRegistered<DatabaseProviderFactory>()) {
      getIt.registerSingleton<DatabaseProviderFactory>(
        const _MongoDbFactoryDelegate(),
      );
    }

    // SchemaService — cache + provider wrapper (storage_module'den sonra
    // register edilir; LocalCache bağımlılığı var).
    if (!getIt.isRegistered<SchemaService>()) {
      getIt.registerLazySingleton<SchemaService>(
        () => SchemaService(
          cache: getIt<LocalCache>(),
          providerFactory: getIt<DatabaseProviderFactory>(),
        ),
      );
    }
  }
}

/// Phase 2 placeholder factory delegate.
///
/// Şu an sadece MongoDB var; ileride kullanıcı ayarlarına göre
/// `DatabaseKind` seçip uygun factory'yi resolve eden bir
/// `SettingsAwareProviderFactory` ile değiştirilecek.
class _MongoDbFactoryDelegate implements DatabaseProviderFactory {
  const _MongoDbFactoryDelegate();

  @override
  DatabaseProvider create() {
    return DatabaseProviderRegistry.instance.create(DatabaseKind.mongodb);
  }

  @override
  DatabaseKind get kind => DatabaseKind.mongodb;
}