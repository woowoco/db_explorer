import 'package:db_explorer_app/core/constants/app_constants.dart';
import 'package:db_explorer_app/core/theme/app_text_styles.dart';
import 'package:db_explorer_app/core/theme/theme_extensions.dart';
import 'package:db_explorer_app/core/theme/uicolors.dart';
import 'package:flutter/material.dart';

/// db_explorer_app theme factory.
///
/// F_AISUBCRIBE'in `app_theme.dart`'ından adapte edildi. Önemli korunan
/// pattern'ler:
/// - `surfaceTint: Colors.transparent` (AI-slop brand-tint fix)
/// - `cardTheme.elevation: 0` (flat design)
/// - Material 3
/// - input radius16, button radius8
/// - `ColorScheme.fromSeed(seedColor: deepPurple)`
///
/// **Çıkarılan** F_AISUBCRIBE-e özel theme extension'lar:
/// - `TimelineColors` (video editor feature)
/// - `ExportScreenColors` (export screen feature)
///
/// db_explorer'a özel eklenen extension'lar:
/// - `DataGridPalette` (BSON tipi semantic renkler)
/// - `EditorPalette` (VSCode-like syntax highlight)
/// - `ConnectionPalette` (connection lifecycle renkleri)
class AppTheme {
  ThemeData lightThemeData() {
    const double borderRadius = AppConstants.radius8;
    const double elevation = AppConstants.elevation10;

    // surfaceTint: Colors.transparent — AI-slop fix (Card/SnackBar/BottomNav
    // brand mor tintlenmesin). Brand rengi sadece interactive accent olarak.
    final lightScheme = ColorScheme.fromSeed(
      seedColor: UIColors.deepPurple,
    ).copyWith(surfaceTint: UIColors.transparent);

    return ThemeData(
      useMaterial3: true,
      colorScheme: lightScheme,
      extensions: [
        AppSpacings.base,
        AppRadii.base,
        DataGridPalette.light(lightScheme),
        EditorPalette.light,
        ConnectionPalette.light(lightScheme),
      ],
      scaffoldBackgroundColor: UIColors.white,
      cardColor: UIColors.white,
      appBarTheme: AppBarTheme(
        backgroundColor: UIColors.white,
        elevation: 0,
        titleTextStyle: AppTextStyles.appName.copyWith(
          color: UIColors.deepPurple,
        ),
      ),
      dividerColor: UIColors.grey200,
      iconTheme: const IconThemeData(color: UIColors.grey600),
      checkboxTheme: CheckboxThemeData(
        side: const BorderSide(color: UIColors.grey400),
        checkColor: WidgetStateProperty.all(UIColors.white),
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? UIColors.deepPurple
              : UIColors.white,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: UIColors.white,
        hintStyle: AppTextStyles.bodySmall.copyWith(color: UIColors.grey500),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: UIColors.grey300),
          borderRadius: BorderRadius.circular(AppConstants.radius16),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: UIColors.deepPurple),
          borderRadius: BorderRadius.circular(AppConstants.radius16),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: UIColors.red),
          borderRadius: BorderRadius.circular(AppConstants.radius16),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: UIColors.red),
          borderRadius: BorderRadius.circular(AppConstants.radius16),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacing16,
          vertical: AppConstants.spacing16,
        ),
      ),
      cardTheme: CardThemeData(
        color: UIColors.white,
        // Flat design: elevation 0 + hairline border strategy.
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radius16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: UIColors.white,
          foregroundColor: UIColors.deepPurple,
          textStyle: AppTextStyles.button,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: UIColors.white,
        elevation: elevation,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: UIColors.deepPurple,
        selectedLabelStyle: AppTextStyles.bodySmall.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      textTheme: _buildTextTheme(),
      primaryTextTheme: _buildTextTheme(),
      snackBarTheme: SnackBarThemeData(
        elevation: elevation,
        backgroundColor: UIColors.red,
        contentTextStyle: AppTextStyles.bodyMedium.copyWith(
          fontWeight: FontWeight.w500,
        ),
        actionTextColor: UIColors.white,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radius16),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: UIColors.deepPurple),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: UIColors.deepPurple,
          foregroundColor: UIColors.white,
          textStyle: AppTextStyles.button,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
      ),
    );
  }

  ThemeData darkThemeData() {
    const double borderRadius = AppConstants.radius8;
    const double elevation = AppConstants.elevation10;

    // Dark scheme — surface siyah (#121212). surfaceTint: Colors.transparent
    // simetri (light ile birebir) korunur.
    final darkScheme = ColorScheme.fromSeed(
      seedColor: UIColors.deepPurple,
      brightness: Brightness.dark,
      surface: const Color(0xFF121212),
    ).copyWith(surfaceTint: UIColors.transparent);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      extensions: [
        AppSpacings.base,
        AppRadii.base,
        DataGridPalette.dark(darkScheme),
        EditorPalette.dark,
        ConnectionPalette.dark(darkScheme),
      ],
      colorScheme: darkScheme,
      scaffoldBackgroundColor: UIColors.black,
      appBarTheme: AppBarTheme(
        backgroundColor: UIColors.black,
        elevation: 0,
        titleTextStyle: AppTextStyles.appName.copyWith(color: UIColors.white),
      ),
      dividerColor: UIColors.grey800,
      iconTheme: const IconThemeData(color: UIColors.grey400),
      checkboxTheme: CheckboxThemeData(
        side: const BorderSide(color: UIColors.grey600),
        checkColor: WidgetStateProperty.all(UIColors.black),
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? UIColors.deepPurple
              : UIColors.black,
        ),
      ),
      cardColor: const Color(0xFF121212),
      cardTheme: CardThemeData(
        color: const Color(0xFF121212),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radius16),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF121212),
        selectedItemColor: UIColors.deepPurple,
        unselectedItemColor: UIColors.grey,
        type: BottomNavigationBarType.fixed,
      ),
      textTheme: _buildTextTheme().apply(
        bodyColor: UIColors.white,
        displayColor: UIColors.white,
        fontFamily: 'Poppins',
      ),
      primaryTextTheme: _buildTextTheme(),
      snackBarTheme: SnackBarThemeData(
        elevation: elevation,
        backgroundColor: UIColors.red,
        contentTextStyle: AppTextStyles.bodyMedium.copyWith(
          fontWeight: FontWeight.w500,
          color: UIColors.white,
        ),
        actionTextColor: UIColors.white,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radius16),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: UIColors.deepPurple),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: UIColors.deepPurple,
          foregroundColor: UIColors.white,
          textStyle: AppTextStyles.button,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: UIColors.deepPurple,
          side: const BorderSide(color: UIColors.deepPurple),
          textStyle: AppTextStyles.button,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1E1E1E),
        hintStyle: AppTextStyles.bodySmall.copyWith(color: UIColors.grey500),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: UIColors.grey700),
          borderRadius: BorderRadius.circular(AppConstants.radius16),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: UIColors.deepPurple),
          borderRadius: BorderRadius.circular(AppConstants.radius16),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: UIColors.red),
          borderRadius: BorderRadius.circular(AppConstants.radius16),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: UIColors.red),
          borderRadius: BorderRadius.circular(AppConstants.radius16),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacing16,
          vertical: AppConstants.spacing16,
        ),
      ),
    );
  }

  TextTheme _buildTextTheme() {
    return TextTheme(
      displayLarge: AppTextStyles.titleLarge,
      displayMedium: AppTextStyles.titleMedium,
      displaySmall: AppTextStyles.headlineLarge,
      headlineLarge: AppTextStyles.headlineLarge,
      headlineMedium: AppTextStyles.headlineMedium,
      headlineSmall: AppTextStyles.headlineSmall,
      titleLarge: AppTextStyles.titleLarge,
      titleMedium: AppTextStyles.titleMedium,
      titleSmall: AppTextStyles.headlineSmall,
      bodyLarge: AppTextStyles.bodyLarge,
      bodyMedium: AppTextStyles.bodyMedium,
      bodySmall: AppTextStyles.bodySmall,
      labelLarge: AppTextStyles.button,
      labelMedium: AppTextStyles.bodyMedium,
      labelSmall: AppTextStyles.caption,
    ).apply(fontFamily: 'Poppins');
  }
}
