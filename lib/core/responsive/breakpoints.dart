import 'package:flutter/widgets.dart';

/// Responsive breakpoint kategorileri.
///
/// db_explorer_app adaptive shell için kullanılır:
/// - `mobile`: telefon form factor (alt navigation bar + tab content)
/// - `tablet`: küçük tablet / landscape phone (3-panel collapsed)
/// - `desktop`: gerçek desktop (3-panel full: sidebar + explorer + workspace)
///
/// Material Design 3 window size class standartlarına yakın:
/// - Compact: <600dp (mobile portrait)
/// - Medium: 600-905dp (tablet / large phone landscape)
/// - Expanded: >905dp (desktop)
enum Breakpoint { mobile, tablet, desktop }

/// Breakpoint sabitleri (logical pixels).
class Breakpoints {
  Breakpoints._();

  /// Mobile üst sınırı (compact).
  static const double mobileMax = 600;

  /// Tablet üst sınırı (medium); desktop ≥ 905.
  static const double tabletMax = 905;
}

/// BuildContext üzerinden aktif breakpoint'i hesapla.
extension BreakpointContext on BuildContext {
  Breakpoint get breakpoint {
    final width = MediaQuery.sizeOf(this).width;
    if (width < Breakpoints.mobileMax) {
      return Breakpoint.mobile;
    } else if (width < Breakpoints.tabletMax) {
      return Breakpoint.tablet;
    }
    return Breakpoint.desktop;
  }

  bool get isMobile => breakpoint == Breakpoint.mobile;
  bool get isTablet => breakpoint == Breakpoint.tablet;
  bool get isDesktop => breakpoint == Breakpoint.desktop;
}
