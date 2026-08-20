import 'package:db_explorer_app/product/app/app_bootstrap.dart';
import 'package:flutter/material.dart';

/// db_explorer_app entry point.
///
/// Akış:
/// 1. WidgetsFlutterBinding.ensureInitialized (minimal init)
/// 2. AppBootstrap.minimalInitialize — ScreenUtil
/// 3. AppBootstrap.fullInitialize — Hive, GetIt, ProviderRegistry
/// 4. runApp(AppBootstrap.buildAppRoot())
Future<void> main() async {
  await AppBootstrap.minimalInitialize();
  await AppBootstrap.fullInitialize();
  runApp(AppBootstrap.buildAppRoot());
}
