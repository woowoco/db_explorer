import 'dart:ui';
import 'package:db_explorer_app/core/constants/app_constants.dart';
import 'package:flutter/material.dart';

/// db_explorer_app ThemeExtension koleksiyonu.
///
/// F_AISUBCRIBE'in `theme_extensions.dart`'ından **jenerik** kısımlar
/// (AppSpacings + AppRadii) birebir adapte edildi. F_AISUBCRIBE'e özel
/// `TimelineColors` ve `ExportScreenColors` (video editor + export screen
/// feature'larına özel) KOPYALANMADI.
///
/// db_explorer'a özel yeni ThemeExtension'lar eklendi:
/// - `DataGridPalette` — semantic renkler (null/bool/number/string/date/ObjectId)
/// - `EditorPalette` — VSCode-like syntax highlight dark mode
/// - `ConnectionPalette` — connection status renkleri (idle/connecting/connected/error)
/// - `SemanticDataColors` — aliaslar (success/warning/error/info)

@immutable
class AppSpacings extends ThemeExtension<AppSpacings> {
  final double s2;
  final double s4;
  final double s6;
  final double s8;
  final double s10;
  final double s12;
  final double s16;
  final double s20;
  final double s24;
  final double s28;
  final double s32;
  final double s36;
  final double s40;
  final double s48;
  final double s60;
  final double s64;
  final double s96;

  const AppSpacings({
    required this.s2,
    required this.s4,
    required this.s6,
    required this.s8,
    required this.s10,
    required this.s12,
    required this.s16,
    required this.s20,
    required this.s24,
    required this.s28,
    required this.s32,
    required this.s36,
    required this.s40,
    required this.s48,
    required this.s60,
    required this.s64,
    required this.s96,
  });

  static const AppSpacings base = AppSpacings(
    s2: AppConstants.spacing2,
    s4: AppConstants.spacing4,
    s6: AppConstants.spacing6,
    s8: AppConstants.spacing8,
    s10: AppConstants.spacing10,
    s12: AppConstants.spacing12,
    s16: AppConstants.spacing16,
    s20: AppConstants.spacing20,
    s24: AppConstants.spacing24,
    s28: AppConstants.spacing28,
    s32: AppConstants.spacing32,
    s36: AppConstants.spacing36,
    s40: AppConstants.spacing40,
    s48: AppConstants.spacing48,
    s60: AppConstants.spacing60,
    s64: AppConstants.spacing64,
    s96: AppConstants.spacing96,
  );

  @override
  AppSpacings copyWith({
    double? s2,
    double? s4,
    double? s6,
    double? s8,
    double? s10,
    double? s12,
    double? s16,
    double? s20,
    double? s24,
    double? s28,
    double? s32,
    double? s36,
    double? s40,
    double? s48,
    double? s60,
    double? s64,
    double? s96,
  }) {
    return AppSpacings(
      s2: s2 ?? this.s2,
      s4: s4 ?? this.s4,
      s6: s6 ?? this.s6,
      s8: s8 ?? this.s8,
      s10: s10 ?? this.s10,
      s12: s12 ?? this.s12,
      s16: s16 ?? this.s16,
      s20: s20 ?? this.s20,
      s24: s24 ?? this.s24,
      s28: s28 ?? this.s28,
      s32: s32 ?? this.s32,
      s36: s36 ?? this.s36,
      s40: s40 ?? this.s40,
      s48: s48 ?? this.s48,
      s60: s60 ?? this.s60,
      s64: s64 ?? this.s64,
      s96: s96 ?? this.s96,
    );
  }

  @override
  AppSpacings lerp(ThemeExtension<AppSpacings>? other, double t) {
    if (other is! AppSpacings) {
      return this;
    }
    return AppSpacings(
      s2: lerpDouble(s2, other.s2, t)!,
      s4: lerpDouble(s4, other.s4, t)!,
      s6: lerpDouble(s6, other.s6, t)!,
      s8: lerpDouble(s8, other.s8, t)!,
      s10: lerpDouble(s10, other.s10, t)!,
      s12: lerpDouble(s12, other.s12, t)!,
      s16: lerpDouble(s16, other.s16, t)!,
      s20: lerpDouble(s20, other.s20, t)!,
      s24: lerpDouble(s24, other.s24, t)!,
      s28: lerpDouble(s28, other.s28, t)!,
      s32: lerpDouble(s32, other.s32, t)!,
      s36: lerpDouble(s36, other.s36, t)!,
      s40: lerpDouble(s40, other.s40, t)!,
      s48: lerpDouble(s48, other.s48, t)!,
      s60: lerpDouble(s60, other.s60, t)!,
      s64: lerpDouble(s64, other.s64, t)!,
      s96: lerpDouble(s96, other.s96, t)!,
    );
  }
}

@immutable
class AppRadii extends ThemeExtension<AppRadii> {
  final double r4;
  final double r6;
  final double r8;
  final double r12;
  final double r16;
  final double r20;
  final double r24;
  final double r32;
  final double r40;

  const AppRadii({
    required this.r4,
    required this.r6,
    required this.r8,
    required this.r12,
    required this.r16,
    required this.r20,
    required this.r24,
    required this.r32,
    required this.r40,
  });

  static const AppRadii base = AppRadii(
    r4: AppConstants.radius4,
    r6: AppConstants.radius6,
    r8: AppConstants.radius8,
    r12: AppConstants.radius12,
    r16: AppConstants.radius16,
    r20: AppConstants.radius20,
    r24: AppConstants.radius24,
    r32: AppConstants.radius32,
    r40: AppConstants.radius40,
  );

  @override
  AppRadii copyWith({
    double? r4,
    double? r6,
    double? r8,
    double? r12,
    double? r16,
    double? r20,
    double? r24,
    double? r32,
    double? r40,
  }) {
    return AppRadii(
      r4: r4 ?? this.r4,
      r6: r6 ?? this.r6,
      r8: r8 ?? this.r8,
      r12: r12 ?? this.r12,
      r16: r16 ?? this.r16,
      r20: r20 ?? this.r20,
      r24: r24 ?? this.r24,
      r32: r32 ?? this.r32,
      r40: r40 ?? this.r40,
    );
  }

  @override
  AppRadii lerp(ThemeExtension<AppRadii>? other, double t) {
    if (other is! AppRadii) {
      return this;
    }
    return AppRadii(
      r4: lerpDouble(r4, other.r4, t)!,
      r6: lerpDouble(r6, other.r6, t)!,
      r8: lerpDouble(r8, other.r8, t)!,
      r12: lerpDouble(r12, other.r12, t)!,
      r16: lerpDouble(r16, other.r16, t)!,
      r20: lerpDouble(r20, other.r20, t)!,
      r24: lerpDouble(r24, other.r24, t)!,
      r32: lerpDouble(r32, other.r32, t)!,
      r40: lerpDouble(r40, other.r40, t)!,
    );
  }
}

/// Data grid hücre tipleri için semantic renkler.
/// Null, boolean, number, string, date, ObjectId, Binary gibi BSON
/// türleri için arka plan / ön plan renkleri. Phase 0'da kullanılmıyor
/// (gerçek data grid Phase 4'te), ama theme sistemi hazır.
@immutable
class DataGridPalette extends ThemeExtension<DataGridPalette> {
  final Color nullBackground;
  final Color nullForeground;

  final Color booleanTrue;
  final Color booleanFalse;

  final Color numberForeground;
  final Color stringForeground;
  final Color dateForeground;
  final Color objectIdForeground;
  final Color binaryForeground;

  final Color rowAltBackground;
  final Color selectionBackground;
  final Color headerBackground;

  const DataGridPalette({
    required this.nullBackground,
    required this.nullForeground,
    required this.booleanTrue,
    required this.booleanFalse,
    required this.numberForeground,
    required this.stringForeground,
    required this.dateForeground,
    required this.objectIdForeground,
    required this.binaryForeground,
    required this.rowAltBackground,
    required this.selectionBackground,
    required this.headerBackground,
  });

  static DataGridPalette light(ColorScheme scheme) => DataGridPalette(
    nullBackground: const Color(0xFFEEEEEE),
    nullForeground: const Color(0xFF9E9E9E),
    booleanTrue: const Color(0xFF2E7D32),
    booleanFalse: const Color(0xFFC62828),
    numberForeground: const Color(0xFF1565C0),
    stringForeground: const Color(0xFF6A1B9A),
    dateForeground: const Color(0xFFEF6C00),
    objectIdForeground: const Color(0xFF00695C),
    binaryForeground: const Color(0xFF455A64),
    rowAltBackground: const Color(0xFFFAFAFA),
    selectionBackground: scheme.primary.withValues(alpha: 0.12),
    headerBackground: const Color(0xFFF5F5F5),
  );

  static DataGridPalette dark(ColorScheme scheme) => DataGridPalette(
    nullBackground: const Color(0xFF2A2A2A),
    nullForeground: const Color(0xFF757575),
    booleanTrue: const Color(0xFF81C784),
    booleanFalse: const Color(0xFFE57373),
    numberForeground: const Color(0xFF64B5F6),
    stringForeground: const Color(0xFFBA68C8),
    dateForeground: const Color(0xFFFFB74D),
    objectIdForeground: const Color(0xFF4DB6AC),
    binaryForeground: const Color(0xFF90A4AE),
    rowAltBackground: const Color(0xFF1E1E1E),
    selectionBackground: scheme.primary.withValues(alpha: 0.20),
    headerBackground: const Color(0xFF252525),
  );

  @override
  DataGridPalette copyWith({
    Color? nullBackground,
    Color? nullForeground,
    Color? booleanTrue,
    Color? booleanFalse,
    Color? numberForeground,
    Color? stringForeground,
    Color? dateForeground,
    Color? objectIdForeground,
    Color? binaryForeground,
    Color? rowAltBackground,
    Color? selectionBackground,
    Color? headerBackground,
  }) {
    return DataGridPalette(
      nullBackground: nullBackground ?? this.nullBackground,
      nullForeground: nullForeground ?? this.nullForeground,
      booleanTrue: booleanTrue ?? this.booleanTrue,
      booleanFalse: booleanFalse ?? this.booleanFalse,
      numberForeground: numberForeground ?? this.numberForeground,
      stringForeground: stringForeground ?? this.stringForeground,
      dateForeground: dateForeground ?? this.dateForeground,
      objectIdForeground: objectIdForeground ?? this.objectIdForeground,
      binaryForeground: binaryForeground ?? this.binaryForeground,
      rowAltBackground: rowAltBackground ?? this.rowAltBackground,
      selectionBackground: selectionBackground ?? this.selectionBackground,
      headerBackground: headerBackground ?? this.headerBackground,
    );
  }

  @override
  DataGridPalette lerp(ThemeExtension<DataGridPalette>? other, double t) {
    if (other is! DataGridPalette) {
      return this;
    }
    return DataGridPalette(
      nullBackground: Color.lerp(nullBackground, other.nullBackground, t)!,
      nullForeground: Color.lerp(nullForeground, other.nullForeground, t)!,
      booleanTrue: Color.lerp(booleanTrue, other.booleanTrue, t)!,
      booleanFalse: Color.lerp(booleanFalse, other.booleanFalse, t)!,
      numberForeground: Color.lerp(
        numberForeground,
        other.numberForeground,
        t,
      )!,
      stringForeground: Color.lerp(
        stringForeground,
        other.stringForeground,
        t,
      )!,
      dateForeground: Color.lerp(dateForeground, other.dateForeground, t)!,
      objectIdForeground: Color.lerp(
        objectIdForeground,
        other.objectIdForeground,
        t,
      )!,
      binaryForeground: Color.lerp(binaryForeground, other.binaryForeground, t)!,
      rowAltBackground: Color.lerp(
        rowAltBackground,
        other.rowAltBackground,
        t,
      )!,
      selectionBackground: Color.lerp(
        selectionBackground,
        other.selectionBackground,
        t,
      )!,
      headerBackground: Color.lerp(headerBackground, other.headerBackground, t)!,
    );
  }
}

/// VSCode-like dark mode syntax highlight renkleri.
/// Phase 0'da `flutter_code_editor` henüz entegre değil; theme sistemi
/// hazır olarak Phase 4'te devreye girer.
@immutable
class EditorPalette extends ThemeExtension<EditorPalette> {
  final Color background;
  final Color foreground;
  final Color selectionBackground;

  final Color keyword; // db, collection, find, aggregate, $match...
  final Color string; // "value"
  final Color number; // 42, 3.14
  final Color boolean; // true, false
  final Color nullValue; // null
  final Color operator; // :, =, ==, !=, <, >
  final Color identifier; // field names, variable names
  @override
  final Color type; // ObjectId, ISODate
  final Color comment; // // comment
  final Color function; // $sum, $avg, $count
  final Color brackets; // {} []

  final Color error;
  final Color warning;

  const EditorPalette({
    required this.background,
    required this.foreground,
    required this.selectionBackground,
    required this.keyword,
    required this.string,
    required this.number,
    required this.boolean,
    required this.nullValue,
    required this.operator,
    required this.identifier,
    required this.type,
    required this.comment,
    required this.function,
    required this.brackets,
    required this.error,
    required this.warning,
  });

  /// VSCode Dark+ inspired.
  static EditorPalette get dark => const EditorPalette(
    background: Color(0xFF1E1E1E),
    foreground: Color(0xFFD4D4D4),
    selectionBackground: Color(0x40ADD6FF),
    keyword: Color(0xFF569CD6), // blue
    string: Color(0xFFCE9178), // brown/orange
    number: Color(0xFFB5CEA8), // green
    boolean: Color(0xFF569CD6), // blue
    nullValue: Color(0xFF569CD6), // blue
    operator: Color(0xFFD4D4D4), // foreground
    identifier: Color(0xFF9CDCFE), // light blue
    type: Color(0xFF4EC9B0), // teal
    comment: Color(0xFF6A9955), // green
    function: Color(0xFFDCDCAA), // yellow
    brackets: Color(0xFFD4D4D4), // foreground
    error: Color(0xFFF44747),
    warning: Color(0xFFDCDCAA),
  );

  /// Light mode: VSCode Light+ inspired.
  static EditorPalette get light => const EditorPalette(
    background: Color(0xFFFFFFFF),
    foreground: Color(0xFF000000),
    selectionBackground: Color(0x40ADD6FF),
    keyword: Color(0xFF0000FF), // blue
    string: Color(0xFFA31515), // dark red
    number: Color(0xFF098658), // green
    boolean: Color(0xFF0000FF), // blue
    nullValue: Color(0xFF0000FF), // blue
    operator: Color(0xFF000000),
    identifier: Color(0xFF001080), // dark blue
    type: Color(0xFF267F99), // teal
    comment: Color(0xFF008000), // green
    function: Color(0xFF795E26), // brown
    brackets: Color(0xFF000000),
    error: Color(0xFFE51400),
    warning: Color(0xFF795E26),
  );

  @override
  EditorPalette copyWith({
    Color? background,
    Color? foreground,
    Color? selectionBackground,
    Color? keyword,
    Color? string,
    Color? number,
    Color? boolean,
    Color? nullValue,
    Color? operator,
    Color? identifier,
    Color? type,
    Color? comment,
    Color? function,
    Color? brackets,
    Color? error,
    Color? warning,
  }) {
    return EditorPalette(
      background: background ?? this.background,
      foreground: foreground ?? this.foreground,
      selectionBackground: selectionBackground ?? this.selectionBackground,
      keyword: keyword ?? this.keyword,
      string: string ?? this.string,
      number: number ?? this.number,
      boolean: boolean ?? this.boolean,
      nullValue: nullValue ?? this.nullValue,
      operator: operator ?? this.operator,
      identifier: identifier ?? this.identifier,
      type: type ?? this.type,
      comment: comment ?? this.comment,
      function: function ?? this.function,
      brackets: brackets ?? this.brackets,
      error: error ?? this.error,
      warning: warning ?? this.warning,
    );
  }

  @override
  EditorPalette lerp(ThemeExtension<EditorPalette>? other, double t) {
    if (other is! EditorPalette) {
      return this;
    }
    return EditorPalette(
      background: Color.lerp(background, other.background, t)!,
      foreground: Color.lerp(foreground, other.foreground, t)!,
      selectionBackground: Color.lerp(
        selectionBackground,
        other.selectionBackground,
        t,
      )!,
      keyword: Color.lerp(keyword, other.keyword, t)!,
      string: Color.lerp(string, other.string, t)!,
      number: Color.lerp(number, other.number, t)!,
      boolean: Color.lerp(boolean, other.boolean, t)!,
      nullValue: Color.lerp(nullValue, other.nullValue, t)!,
      operator: Color.lerp(operator, other.operator, t)!,
      identifier: Color.lerp(identifier, other.identifier, t)!,
      type: Color.lerp(type, other.type, t)!,
      comment: Color.lerp(comment, other.comment, t)!,
      function: Color.lerp(function, other.function, t)!,
      brackets: Color.lerp(brackets, other.brackets, t)!,
      error: Color.lerp(error, other.error, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
    );
  }
}

/// Connection lifecycle state renkleri.
@immutable
class ConnectionPalette extends ThemeExtension<ConnectionPalette> {
  final Color idle;
  final Color connecting;
  final Color connected;
  final Color error;
  final Color disconnected;

  const ConnectionPalette({
    required this.idle,
    required this.connecting,
    required this.connected,
    required this.error,
    required this.disconnected,
  });

  static ConnectionPalette light(ColorScheme scheme) => const ConnectionPalette(
    idle: Color(0xFF9E9E9E),
    connecting: Color(0xFFFFA726),
    connected: Color(0xFF2E7D32),
    error: Color(0xFFC62828),
    disconnected: Color(0xFF616161),
  );

  static ConnectionPalette dark(ColorScheme scheme) => const ConnectionPalette(
    idle: Color(0xFF757575),
    connecting: Color(0xFFFFB74D),
    connected: Color(0xFF81C784),
    error: Color(0xFFE57373),
    disconnected: Color(0xFF9E9E9E),
  );

  @override
  ConnectionPalette copyWith({
    Color? idle,
    Color? connecting,
    Color? connected,
    Color? error,
    Color? disconnected,
  }) {
    return ConnectionPalette(
      idle: idle ?? this.idle,
      connecting: connecting ?? this.connecting,
      connected: connected ?? this.connected,
      error: error ?? this.error,
      disconnected: disconnected ?? this.disconnected,
    );
  }

  @override
  ConnectionPalette lerp(ThemeExtension<ConnectionPalette>? other, double t) {
    if (other is! ConnectionPalette) {
      return this;
    }
    return ConnectionPalette(
      idle: Color.lerp(idle, other.idle, t)!,
      connecting: Color.lerp(connecting, other.connecting, t)!,
      connected: Color.lerp(connected, other.connected, t)!,
      error: Color.lerp(error, other.error, t)!,
      disconnected: Color.lerp(disconnected, other.disconnected, t)!,
    );
  }
}

/// BuildContext extension'ları — F_AISUBCRIBE standardı.
extension AppThemeContext on BuildContext {
  AppSpacings get spacing => Theme.of(this).extension<AppSpacings>()!;
  AppRadii get radius => Theme.of(this).extension<AppRadii>()!;
  DataGridPalette get dataGrid => Theme.of(this).extension<DataGridPalette>()!;
  EditorPalette get editor => Theme.of(this).extension<EditorPalette>()!;
  ConnectionPalette get connection => Theme.of(this).extension<ConnectionPalette>()!;
}
