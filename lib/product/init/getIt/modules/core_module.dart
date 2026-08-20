import 'package:db_explorer_app/core/utils/app_logger.dart';
import 'package:db_explorer_app/presentation/connection_cubit.dart';
import 'package:db_explorer_app/presentation/theme_cubit.dart';
import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';

/// GetIt modülü — core / app-level servisler.
///
/// - Logger (global)
/// - ThemeCubit / ConnectionCubit (singleton Cubits)
/// - AppCubit StorageModule sonrasında register edilir (AppSettings bağımlılığı)
class CoreModule {
  CoreModule._();

  static void register(GetIt getIt) {
    getIt.registerLazySingleton<Logger>(getLogger);

    // Cubit'ler — singleton olarak register edilir; AppBootstrap'ta
    // MultiBlocProvider ile widget tree'ye inject edilir.
    getIt.registerLazySingleton<ThemeCubit>(ThemeCubit.new);
    getIt.registerLazySingleton<ConnectionCubit>(ConnectionCubit.new);
  }
}
