import 'package:flutter/material.dart';

/// Uygulama genelinde kullanılan renk sabitleri.
///
/// db_explorer_app için F_AISUBCRIBE'in `UIColors`'ından adapte edildi.
/// **Çıkarılan** F_AISUBCRIBE-e özel renkler:
/// - storeBgDark, cinematicBlack/darkPurpleSurface/cinematicPurple/cinematicPurpleMid
/// - softGold, cinematicTextPrimary/Secondary, inputDarkBg, glassmorphicSurface
/// (Bunlar login redesign'a özeldi; db_explorer'da karşılığı yok.)
///
/// Korunan jenerik token'lar:
/// - deepPurple #6F31DA (brand primary), semantic aliaslar (success/warning/error/info),
/// - grey scale (grey100..grey800), pure black/white/transparent.
class UIColors {
  // ===== BASIC COLORS =====
  static const Color grey = Color(0xFF808080);
  static const Color slateGrey = Color(0xFF64748b);
  static const Color whiteGrey = Color.fromARGB(151, 245, 245, 245);

  /// Şeffaf renk
  static const Color transparent = Color(0x00000000);

  /// Beyaz renk
  static const Color white = Color(0xFFFFFFFF);
  static const Color ligthWhite = Color.fromARGB(255, 245, 250, 250);

  static const Color blue = Color(0xFF2196F3);

  /// Kırmızı renk
  static const Color red = Color(0xFFF44336);

  /// Siyah renk
  static const Color black = Color(0xFF000000);
  static const Color lightBlack = Color(0xFF1a1a1a);

  static const Color orange = Color(0xFFFF9800);
  static const Color indigo = Color(0xFF3F51B5);
  static const Color teal = Color(0xFF009688);
  static const Color pink = Color(0xFFE91E63);
  static const Color cyan = Color(0xFF00BCD4);
  static const Color amber = Color(0xFFFFC107);

  // ===== THEME COLORS =====
  /// Ana tema rengi — Deep Purple
  /// F_AISUBCRIBE tutarlılığı: `#6F31DA`
  static const Color deepPurple = Color.fromRGBO(111, 49, 218, 1);

  static const Color deepPurpleShade = Color.fromRGBO(54, 3, 150, 1);

  /// Açık mor — vurgu / soft backgrounds
  static const Color purpleLight = Color(0xFFE0D4FF);

  static const Color whtiestPurple = Color.fromARGB(255, 172, 129, 247);

  /// Açık yeşil renk (144, 238, 144)
  static const Color lightGreen = Color.fromRGBO(144, 238, 144, 1);
  static const Color green = Color(0xFF4CAF50);

  // ===== ACCENT COLORS =====
  /// Coral red — badges / notifications
  static const Color coralRed = Color(0xFFFF6B6B);

  /// Gold — premium accents
  static const Color gold = Color(0xFFFFD700);

  /// Orange-gold — gradient ler için
  static const Color goldOrange = Color(0xFFFFA500);

  // ===== GREY SCALE =====
  static const Color orange100 = Color(0xFFFFE0B2);
  static const Color red100 = Color(0xFFFFCDD2);
  static const Color grey100 = Color(0xFFF5F5F5);
  static const Color grey200 = Color(0xFFEEEEEE);
  static const Color grey300 = Color(0xFFE0E0E0);
  static const Color grey400 = Color(0xFFBDBDBD);
  static const Color grey500 = Color(0xFF9E9E9E);
  static const Color grey600 = Color(0xFF757575);
  static const Color grey700 = Color(0xFF616161);
  static const Color grey800 = Color(0xFF424242);
  static const Color black87 = Color(0xDD000000);

  // ===== DATABASE-SPECIFIC PALETTE =====
  /// MongoDB brand green — connection badges / status dots
  static const Color mongoGreen = Color(0xFF00684A);

  // ===== ALIASES =====
  static const Color background = Color(0xFFF8F9FE); // Premium Light Grey
  static const Color primary = deepPurple;
  static const Color error = red;
  static const Color warning = orange;
  static const Color success = green;
  static const Color info = blue;
}
