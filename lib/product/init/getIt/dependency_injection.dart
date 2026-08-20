import 'package:db_explorer_app/product/init/getIt/modules/ai_module.dart';
import 'package:db_explorer_app/product/init/getIt/modules/core_module.dart';
import 'package:db_explorer_app/product/init/getIt/modules/database_module.dart';
import 'package:db_explorer_app/product/init/getIt/modules/storage_module.dart';
import 'package:db_explorer_app/product/providers_registry/builtin.dart';
import 'package:get_it/get_it.dart';

/// GetIt DI orchestration.
///
/// F_AISUBCRIBE'in `lib/product/init/getIt/dependency_injection.dart`
/// pattern'i sadeleştirilerek uygulandı. Modüler registration:
/// 1. CoreModule — logger, app-level Cubits
/// 2. StorageModule (async) — SharedPreferences init, settings/secure store
/// 3. DatabaseModule — provider registry
/// 4. AiModule — AI provider registry + ai_cubit
///
/// Sonra `registerBuiltinProviders()` ile built-in factory'ler register.
class GetItInjections {
  GetItInjections._();

  /// Sync modüller — SharedPreferences init gerektirmeyen.
  static void registerSync(GetIt getIt) {
    CoreModule.register(getIt);
    DatabaseModule.register(getIt);
    AiModule.register(getIt);
  }

  /// Async modüller — SharedPreferences init gerektiren.
  static Future<void> registerAsync(GetIt getIt) async {
    await StorageModule.initAsync(getIt);
  }

  /// Built-in provider factory'leri registry'lere yaz.
  static void registerProviders() {
    registerBuiltinProviders();
  }
}
