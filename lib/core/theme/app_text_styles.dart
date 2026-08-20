// ignore_for_file: avoid_text_style_literal, avoid_hardcoded_poppins

import 'package:db_explorer_app/core/theme/uicolors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// db_explorer_app için text style koleksiyonu.
///
/// F_AISUBCRIBE'in `app_text_styles.dart`'ından adapte edildi.
/// **Çıkarılan** cinematic stiller (login redesign'a özel):
/// - cinematicWelcome, cinematicSubtitle, cinematicLabel, cinematicHint
///
/// Korunan jenerik stiller: Poppins font, ScreenUtil `_getResponsiveSize` helper.
class AppTextStyles {
  /// ScreenUtil initialize edilmeden çağrılırsa `.sp` exception fırlatır;
  /// bu durumda raw değeri döndürür (early call safety).
  static double _getResponsiveSize(double size) {
    try {
      return size.sp;
    } catch (_) {
      return size;
    }
  }

  // ===== STANDARD STYLES =====

  static TextStyle get headlineLarge => TextStyle(
    fontFamily: 'Poppins',
    fontSize: _getResponsiveSize(20),
    fontWeight: FontWeight.w500,
  );

  static TextStyle get headlineMedium => TextStyle(
    fontFamily: 'Poppins',
    fontSize: _getResponsiveSize(18),
    fontWeight: FontWeight.w500,
  );

  static TextStyle get headlineSmall => TextStyle(
    fontFamily: 'Poppins',
    fontSize: _getResponsiveSize(16),
    fontWeight: FontWeight.w600,
  );

  static TextStyle get titleLarge => TextStyle(
    fontFamily: 'Poppins',
    fontSize: _getResponsiveSize(30),
    fontWeight: FontWeight.w900,
  );

  static TextStyle get titleMedium => TextStyle(
    fontFamily: 'Poppins',
    fontSize: _getResponsiveSize(24),
    fontWeight: FontWeight.w700,
  );

  static TextStyle get bodyLarge => TextStyle(
    fontFamily: 'Poppins',
    fontSize: _getResponsiveSize(16),
    fontWeight: FontWeight.w400,
  );

  static TextStyle get bodyMedium => TextStyle(
    fontFamily: 'Poppins',
    fontSize: _getResponsiveSize(14),
    fontWeight: FontWeight.w400,
  );

  static TextStyle get bodySmall => TextStyle(
    fontFamily: 'Poppins',
    fontSize: _getResponsiveSize(12),
    fontWeight: FontWeight.w400,
  );

  static TextStyle get button => TextStyle(
    fontFamily: 'Poppins',
    fontSize: _getResponsiveSize(16),
    fontWeight: FontWeight.w500,
  );

  static TextStyle get caption => TextStyle(
    fontFamily: 'Poppins',
    fontSize: _getResponsiveSize(10),
    fontWeight: FontWeight.w400,
  );

  static TextStyle get appName => TextStyle(
    fontFamily: 'Poppins',
    fontSize: _getResponsiveSize(16),
    fontWeight: FontWeight.w900,
  );

  static TextStyle get subtitle => TextStyle(
    fontFamily: 'Poppins',
    fontSize: _getResponsiveSize(14),
    fontWeight: FontWeight.w400,
    color: UIColors.grey,
  );

  // ===== MONO STYLES (Query editor + code blocks) =====

  /// Code editor base — query editor için monospace fallback.
  /// Phase 0'da gerçek font seçimi yapılmadı; F_AISUBCRIBE tutarlılığı
  /// için Poppins family default olarak kullanılıyor.
  /// Phase 4'te `flutter_code_editor` gerçek font'unu kullanacak.
  static TextStyle get codeBase => TextStyle(
    fontFamily: 'Poppins',
    fontSize: _getResponsiveSize(13),
    fontWeight: FontWeight.w400,
  );

  // Ek stiller projedeki kullanımlara göre eklenebilir
}
