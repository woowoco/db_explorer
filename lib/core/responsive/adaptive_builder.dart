import 'package:db_explorer_app/core/responsive/breakpoints.dart';
import 'package:flutter/widgets.dart';

/// Breakpoint'e göre farklı widget döndüren layout builder.
///
/// Tüm alanlar opsiyonel; sağlanmayan alan bir üst/alt breakpoint'ten
/// miras alır (tablet verilmemişse mobile'dan miras alır vb.).
///
/// Kullanım:
/// ```dart
/// AdaptiveLayoutBuilder(
///   mobile: (_) => const MobileShell(),
///   tablet: (_) => const TabletShell(),
///   desktop: (_) => const DesktopShell(),
/// )
/// ```
class AdaptiveLayoutBuilder extends StatelessWidget {
  const AdaptiveLayoutBuilder({
    super.key,
    this.mobile,
    this.tablet,
    required this.desktop,
  });

  final WidgetBuilder? mobile;
  final WidgetBuilder? tablet;
  final WidgetBuilder desktop;

  @override
  Widget build(BuildContext context) {
    final breakpoint = context.breakpoint;
    switch (breakpoint) {
      case Breakpoint.mobile:
        if (mobile != null) return Builder(builder: mobile!);
        if (tablet != null) return Builder(builder: tablet!);
        return Builder(builder: desktop);
      case Breakpoint.tablet:
        if (tablet != null) return Builder(builder: tablet!);
        if (mobile != null) return Builder(builder: mobile!);
        return Builder(builder: desktop);
      case Breakpoint.desktop:
        return Builder(builder: desktop);
    }
  }
}
