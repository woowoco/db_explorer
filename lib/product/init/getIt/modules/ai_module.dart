import 'package:db_explorer_app/infrastructure/registry/ai_provider_registry.dart';
import 'package:db_explorer_app/presentation/ai_cubit.dart';
import 'package:get_it/get_it.dart';

/// GetIt modülü — AI provider registry + ai cubit.
class AiModule {
  AiModule._();

  static void register(GetIt getIt) {
    getIt.registerSingleton<AiProviderRegistry>(AiProviderRegistry.instance);
    getIt.registerLazySingleton<AiCubit>(AiCubit.new);
  }
}
