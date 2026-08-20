import 'package:db_explorer_app/core/theme/app_theme.dart';
import 'package:db_explorer_app/presentation/theme_cubit.dart';
import 'package:db_explorer_app/product/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// db_explorer_app root widget — `MaterialApp.router` + theme switch.
///
/// Adaptive shell GoRouter üzerinden yönetilir; burada sadece tema +
/// router config var.
class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme();
    final router = buildAppRouter();

    return BlocBuilder<ThemeCubit, ThemeMode>(
      builder: (context, mode) {
        return MaterialApp.router(
          title: 'db_explorer_app',
          debugShowCheckedModeBanner: false,
          theme: theme.lightThemeData(),
          darkTheme: theme.darkThemeData(),
          themeMode: mode,
          routerConfig: router,
        );
      },
    );
  }
}
