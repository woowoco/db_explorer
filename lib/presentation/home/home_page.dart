import 'package:db_explorer_app/core/responsive/adaptive_builder.dart';
import 'package:db_explorer_app/presentation/home/home_shell_desktop.dart';
import 'package:db_explorer_app/presentation/home/home_shell_mobile.dart';
import 'package:flutter/material.dart';

/// db_explorer_app home — breakpoint'e göre desktop veya mobile shell.
///
/// Adaptive shell pattern (F_AISUBCRIBE tutarlılığı):
/// - Desktop / tablet: 3-panel layout (sidebar + explorer + workspace)
/// - Mobile: bottom nav + tab content
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdaptiveLayoutBuilder(
      mobile: mobileFactory,
      desktop: desktopFactory,
    );
  }
}

Widget mobileFactory(BuildContext _) => const HomeShellMobile();
Widget desktopFactory(BuildContext _) => const HomeShellDesktop();
