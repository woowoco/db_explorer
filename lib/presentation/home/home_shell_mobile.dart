import 'package:db_explorer_app/presentation/ai_assistant/ai_assistant_page.dart';
import 'package:db_explorer_app/presentation/connections/connections_page.dart';
import 'package:db_explorer_app/presentation/explorer/explorer_page.dart';
import 'package:db_explorer_app/presentation/workspace/workspace_page.dart';
import 'package:flutter/material.dart';

/// Mobile shell — bottom navigation + tab content.
///
/// Phase 0'da 4 tab: Workspace, Connections, Explorer, AI Assistant.
/// Settings'e app bar action ile erişilir.
class HomeShellMobile extends StatefulWidget {
  const HomeShellMobile({super.key});

  @override
  State<HomeShellMobile> createState() => _HomeShellMobileState();
}

class _HomeShellMobileState extends State<HomeShellMobile> {
  int _index = 0;

  static const List<Widget> _pages = [
    WorkspacePage(),
    ConnectionsPage(),
    ExplorerPage(),
    AiAssistantPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.code_outlined),
            selectedIcon: Icon(Icons.code),
            label: 'Workspace',
          ),
          NavigationDestination(
            icon: Icon(Icons.storage_outlined),
            selectedIcon: Icon(Icons.storage),
            label: 'Connections',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_tree_outlined),
            selectedIcon: Icon(Icons.account_tree),
            label: 'Explorer',
          ),
          NavigationDestination(
            icon: Icon(Icons.psychology_outlined),
            selectedIcon: Icon(Icons.psychology),
            label: 'AI',
          ),
        ],
      ),
    );
  }
}
