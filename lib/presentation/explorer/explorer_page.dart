import 'package:db_explorer_app/presentation/home/placeholder_panel.dart';
import 'package:flutter/material.dart';

/// Explorer page — schema tree (Phase 3+).
class ExplorerPage extends StatelessWidget {
  const ExplorerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Explorer')),
      body: const PlaceholderPanel(
        title: 'Schema Explorer',
        subtitle: 'Hierarchical view: database > collection > field > index.',
        phaseNumber: 3,
        icon: Icons.account_tree_outlined,
      ),
    );
  }
}
