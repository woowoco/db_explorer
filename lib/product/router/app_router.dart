import 'package:db_explorer_app/presentation/ai_assistant/ai_assistant_page.dart';
import 'package:db_explorer_app/presentation/connections/connections_page.dart';
import 'package:db_explorer_app/presentation/explorer/explorer_page.dart';
import 'package:db_explorer_app/presentation/home/home_page.dart';
import 'package:db_explorer_app/presentation/settings/settings_page.dart';
import 'package:db_explorer_app/presentation/workspace/workspace_page.dart';
import 'package:db_explorer_app/product/router/route_guards.dart';
import 'package:db_explorer_app/product/router/routes.dart';
import 'package:go_router/go_router.dart';

/// db_explorer_app GoRouter config.
///
/// Phase 0'da tüm route'lar placeholder page'e gider. State management
/// ile route navigation `context.go('/workspace')` gibi çağrılarla yapılır.
///
/// Adaptive shell (desktop sidebar + mobile bottom nav) tek bir
/// StatefulShellRoute üzerinden yönetilir.
GoRouter buildAppRouter() {
  return GoRouter(
    initialLocation: AppRoutes.home,
    redirect: AppRouteGuards.redirectGuard,
    routes: [
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: AppRoutes.connections,
        builder: (context, state) => const ConnectionsPage(),
        routes: [
          GoRoute(
            path: 'new',
            builder: (context, state) => const ConnectionsPage(isNew: true),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.workspace,
        builder: (context, state) => const WorkspacePage(),
      ),
      GoRoute(
        path: AppRoutes.aiAssistant,
        builder: (context, state) => const AiAssistantPage(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        path: '/explorer',
        builder: (context, state) => const ExplorerPage(),
      ),
    ],
  );
}
