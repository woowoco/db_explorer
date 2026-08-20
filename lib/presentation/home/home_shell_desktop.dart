import 'package:db_explorer_app/core/theme/uicolors.dart';
import 'package:db_explorer_app/presentation/ai_assistant/ai_assistant_page.dart';
import 'package:db_explorer_app/presentation/connections/connections_page.dart';
import 'package:db_explorer_app/presentation/explorer/explorer_page.dart';
import 'package:db_explorer_app/presentation/workspace/workspace_page.dart';
import 'package:flutter/material.dart';

/// 3-panel desktop layout: Sidebar (260) + Explorer (320) + Workspace (Expanded).
///
/// AI Assistant paneli Workspace'in sağında drawer olarak açılır (Phase 4+).
class HomeShellDesktop extends StatelessWidget {
  const HomeShellDesktop({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Row(
        children: [
          // Sidebar — primary navigation
          ColoredBox(
            color: theme.colorScheme.surface,
            child: const SizedBox(width: 260, child: ConnectionsPage()),
          ),
          VerticalDivider(width: 1, color: theme.dividerColor),
          // Explorer — schema tree
          const SizedBox(width: 320, child: ExplorerPage()),
          VerticalDivider(width: 1, color: theme.dividerColor),
          // Workspace — query editor + results
          Expanded(
            child: Column(
              children: [
                const Expanded(child: WorkspacePage()),
                Divider(height: 1, color: theme.dividerColor),
                SizedBox(
                  height: 240,
                  child: ColoredBox(
                    color: UIColors.grey100.withValues(alpha: 0.4),
                    child: const AiAssistantPage(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
