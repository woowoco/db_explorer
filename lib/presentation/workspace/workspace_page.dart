import 'package:db_explorer_app/presentation/home/placeholder_panel.dart';
import 'package:flutter/material.dart';

/// Query workspace — Phase 4'te gerçek query editor + results.
class WorkspacePage extends StatelessWidget {
  const WorkspacePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Workspace')),
      body: const PlaceholderPanel(
        title: 'Query Workspace',
        subtitle: 'Query editor + result data grid + tabs.',
        phaseNumber: 4,
        icon: Icons.code_outlined,
      ),
    );
  }
}
