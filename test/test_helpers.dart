import 'package:db_explorer_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart' hide DataRow;

/// Test helper — db_explorer_app'ın gerçek theme'sini (DataGridPalette,
/// EditorPalette, ConnectionPalette, AppSpacings, AppRadii extension'ları)
/// MaterialApp'e inject eder.
///
/// Test'ler default MaterialApp kullanırsa bu ThemeExtension'lar null olur
/// ve `context.dataGrid`/`context.editor` gibi extension getter'ları
/// null-check `!` ile patlar. Bu helper ile test ortamı production theme'sini
/// birebir kullanır.
Widget wrapWithAppTheme({required Widget child, Brightness brightness = Brightness.light}) {
  final theme = brightness == Brightness.light
      ? AppTheme().lightThemeData()
      : AppTheme().darkThemeData();
  return MaterialApp(
    theme: theme,
    home: Scaffold(body: child),
  );
}
