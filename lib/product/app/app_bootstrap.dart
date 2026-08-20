import 'package:db_explorer_app/core/utils/app_logger.dart';
import 'package:db_explorer_app/infrastructure/registry/ai_provider_registry.dart';
import 'package:db_explorer_app/infrastructure/registry/database_provider_registry.dart';
import 'package:db_explorer_app/infrastructure/storage/settings.dart';
import 'package:db_explorer_app/presentation/ai_cubit.dart';
import 'package:db_explorer_app/presentation/app_cubit.dart';
import 'package:db_explorer_app/presentation/theme_cubit.dart';
import 'package:db_explorer_app/product/app/app.dart';
import 'package:db_explorer_app/product/init/getIt/dependency_injection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// AppBootstrap — F_AISUBCRIBE'in `app_bootstrap.dart` prensibinden
/// sadeleştirilmiş.
///
/// Akış:
/// 1. WidgetsFlutterBinding.ensureInitialized (main.dart)
/// 2. AppBootstrap.minimalInitialize — ScreenUtil, logger
/// 3. AppBootstrap.fullInitialize — Hive, SharedPreferences, GetIt,
///    ProviderRegistry, MultiBlocProvider root
///
/// Önemli: AI binding (llama.cpp) heavy init olduğu için post-frame
/// callback'inde yapılmalı (Phase 7+); Phase 0'da bu adım stub.
class AppBootstrap {
  AppBootstrap._();

  /// Minimal init — runApp'tan ÖNCE yapılmalı (UI thread block'lamaz).
  static Future<void> minimalInitialize() async {
    WidgetsFlutterBinding.ensureInitialized();
    // ScreenUtil setup — design size iPhone 14 Pro.
    await ScreenUtil.ensureScreenSize();
  }

  /// Full init — runApp içinde / pre-runApp'ta.
  static Future<void> fullInitialize() async {
    final log = getLogger('bootstrap');

    // Hive init (encrypted box için)
    await Hive.initFlutter();
    log.i('Hive initialized');

    // GetIt DI
    final getIt = GetIt.instance;
    GetItInjections.registerSync(getIt);
    await GetItInjections.registerAsync(getIt);
    // Settings async init sonrası hazır; provider registration'da
    // AppSettings.aiMode'a göre aktif AI provider seçilecek.
    GetItInjections.registerProviders(getIt<AppSettings>());
    log.i('GetIt + providers registered');

    // Smoke test — storage layer çalışıyor mu?
    final settings = getIt<AppSettings>();
    final settingsOk = await settings.ping();
    log.i('Settings smoke: $settingsOk');

    // AI default provider detection
    final aiRegistry = getIt<AiProviderRegistry>();
    final defaultProvider = await aiRegistry.defaultProvider();
    log.i('AI default provider: ${defaultProvider?.id ?? 'none'}');

    // Database providers smoke
    final dbRegistry = getIt<DatabaseProviderRegistry>();
    log.i('Database providers: ${dbRegistry.all.map((f) => f.kind.name).join(', ')}');

    log.i('Phase 0 init OK');
  }

  /// Root widget — runApp'a verilecek.
  static Widget buildAppRoot() {
    final getIt = GetIt.instance;

    return MultiBlocProvider(
      providers: [
        BlocProvider<ThemeCubit>.value(value: getIt<ThemeCubit>()),
        BlocProvider<AppCubit>.value(value: getIt<AppCubit>()),
        BlocProvider<AiCubit>.value(value: getIt<AiCubit>()),
      ],
      child: const AppRoot(),
    );
  }
}
