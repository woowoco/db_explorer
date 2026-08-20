/// Uygulama genelinde kullanılan sabit değerler
/// Font boyutları, spacing, radius, elevation gibi UI sabitlerini içerir.
///
/// F_AISUBCRIBE'in `app_constants.dart`'ından birebir kopyalanmıştır
/// (jenerik design tokens — feature-spesifik olan `appName` ve
/// `resultContentHeight` / `buttonWidth336` / `forgotPasswordMaxHeight`
/// çıkarılmıştır, bunlar F_AISUBCRIBE'e özeldi).
class AppConstants {
  /// Private constructor - singleton pattern için
  AppConstants._();

  // ===== FONT SIZE CONSTANTS =====
  /// Küçük font boyutları (8-12px)
  static const double fontSize8 = 8.0;
  static const double fontSize9 = 9.0;
  static const double fontSize10 = 10.0;
  static const double fontSize11 = 11.0;
  static const double fontSize12 = 12.0;

  /// Orta font boyutları (14-18px)
  static const double fontSize14 = 14.0;
  static const double fontSize16 = 16.0;
  static const double fontSize18 = 18.0;

  /// Büyük font boyutları (20px+)
  static const double fontSize20 = 20.0;
  static const double fontSize24 = 24.0;
  static const double fontSize32 = 32.0;
  static const double fontSize36 = 36.0;
  static const double fontSize96 = 96.0;

  // ===== ICON SIZE CONSTANTS =====
  /// Küçük iconlar (10-14px)
  static const double iconSize10 = 10.0;
  static const double iconSize11 = 11.0;
  static const double iconSize12 = 12.0;
  static const double iconSize14 = 14.0;
  static const double iconSize16 = 16.0;
  static const double iconSize20 = 20.0;
  static const double iconSize24 = 24.0;
  static const double iconSize48 = 48.0;

  // ===== SPACING CONSTANTS =====
  /// Widget'lar arası boşluk değerleri
  /// Küçük boşluklar (2-8px)
  static const double spacing2 = 2.0;
  static const double spacing4 = 4.0;
  static const double spacing6 = 6.0;
  static const double spacing8 = 8.0;
  static const double spacing10 = 10.0;
  static const double spacing12 = 12.0;

  /// Orta boşluklar (12-20px)
  static const double spacing16 = 16.0;
  static const double spacing20 = 20.0;

  /// Büyük boşluklar (24px+)
  static const double spacing24 = 24.0;
  static const double spacing28 = 28.0;
  static const double spacing32 = 32.0;
  static const double spacing36 = 36.0;
  static const double spacing40 = 40.0;
  static const double spacing48 = 48.0;
  static const double spacing60 = 60.0;
  static const double spacing64 = 64.0;
  static const double spacing96 = 96.0;

  // ===== SIZE CONSTANTS =====
  /// Özel widget boyutları
  static const double size40 = 40.0;
  static const double maxContentWidth = 600.0;

  /// AppBar yüksekliği
  static const double appBarHeight = 80.0;

  /// Divider yüksekliği
  static const double dividerHeight = 24.0;

  /// Badge boyutu
  static const double badgeSize = 8.0;

  // ===== BLUR CONSTANTS =====
  /// BackdropFilter blur değerleri
  static const double blurSigma10 = 10.0;
  static const double blurSigma4 = 4.0;

  // ===== LETTER SPACING CONSTANTS =====
  /// Text letter spacing değerleri
  static const double letterSpacing05 = 0.5;
  static const double letterSpacing12 = 1.2;

  // ===== RADIUS CONSTANTS =====
  /// Border radius değerleri
  /// Standart radius değerleri
  static const double radius4 = 4.0;
  static const double radius6 = 6.0;
  static const double radius8 = 8.0;
  static const double radius12 = 12.0;
  static const double radius16 = 16.0;
  static const double radius20 = 20.0;
  static const double radius24 = 24.0;
  static const double radius32 = 32.0;
  static const double radius40 = 40.0;

  // ===== ELEVATION CONSTANTS =====
  /// Shadow elevation değerleri
  /// Düşük elevation (5px)
  static const double elevation5 = 5.0;

  /// Yüksek elevation (10px)
  static const double elevation10 = 10.0;

  // ===== OTHER CONSTANTS =====
  /// Scale factors
  static const double scaleFactor1_5 = 1.5;

  // ===== ALPHA CONSTANTS (0-255 int values for withAlpha) =====
  /// withAlpha() için int değerler
  static const int alpha10 = 10;
  static const int alpha100 = 100;
  static const int alpha150 = 150;
  static const int alpha220 = 220;
  static const int alpha230 = 230;
  static const int alpha235 = 235;

  // ===== OPACITY CONSTANTS (0.0-1.0 double values for withValues) =====
  /// withValues(alpha: x) için double değerler
  static const double opacity005 = 0.05;
  static const double opacity008 = 0.08;
  static const double opacity01 = 0.1;
  static const double opacity015 = 0.15;
  static const double opacity02 = 0.2;
  static const double opacity025 = 0.25;
  static const double opacity03 = 0.3;
  static const double opacity05 = 0.5;
  static const double opacity07 = 0.7;
  static const double opacity08 = 0.8;
  static const double opacity095 = 0.95;
  static const double opacity098 = 0.98;
}
