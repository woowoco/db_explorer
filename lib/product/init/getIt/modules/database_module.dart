import 'package:db_explorer_app/infrastructure/registry/database_provider_registry.dart';
import 'package:get_it/get_it.dart';

/// GetIt modülü — database provider registry.
///
/// Built-in provider factory'ler `product/providers_registry/builtin.dart`
/// üzerinden kayıt edilir; burada sadece registry singleton olarak
/// expose edilir.
class DatabaseModule {
  DatabaseModule._();

  static void register(GetIt getIt) {
    // DatabaseProviderRegistry zaten singleton; burada sadece
    // erişim için bir delegate getIt'ye konur.
    getIt.registerSingleton<DatabaseProviderRegistry>(
      DatabaseProviderRegistry.instance,
    );
  }
}
