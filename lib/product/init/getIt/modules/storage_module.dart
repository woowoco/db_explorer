import 'package:db_explorer_app/infrastructure/storage/local_cache.dart';
import 'package:db_explorer_app/infrastructure/storage/secure_connection_store.dart';
import 'package:db_explorer_app/infrastructure/storage/settings.dart';
import 'package:db_explorer_app/presentation/app_cubit.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// GetIt modülü — storage katmanı.
class StorageModule {
  StorageModule._();

  /// SharedPreferences async init gerektirdiği için bu modül
  /// ayrı bir async init fonksiyonuna sahip. Bootstrap'tan
  /// `await StorageModule.initAsync(getIt)` ile çağrılır.
  static Future<void> initAsync(GetIt getIt) async {
    final prefs = await SharedPreferences.getInstance();

    if (!getIt.isRegistered<AppSettings>()) {
      getIt.registerSingleton<AppSettings>(AppSettings(prefs));
    }
    if (!getIt.isRegistered<SecureConnectionStore>()) {
      getIt.registerLazySingleton<SecureConnectionStore>(
        SecureConnectionStore.new,
      );
    }
    if (!getIt.isRegistered<LocalCache>()) {
      getIt.registerLazySingleton<LocalCache>(LocalCache.new);
    }

    // AppCubit AppSettings bağımlılığı olduğu için burada register.
    if (!getIt.isRegistered<AppCubit>()) {
      getIt.registerLazySingleton<AppCubit>(() => AppCubit(getIt<AppSettings>()));
    }
  }
}
