import 'package:db_explorer_app/presentation/home/placeholder_panel.dart';
import 'package:flutter/material.dart';

/// AI Query Copilot panel — Phase 7'de gerçek implementasyon.
class AiAssistantPage extends StatelessWidget {
  const AiAssistantPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Assistant')),
      body: const PlaceholderPanel(
        title: 'AI Query Copilot',
        subtitle:
            'Schema-only context. Read-only queries. No write authority.',
        phaseNumber: 7,
        icon: Icons.psychology_outlined,
      ),
    );
  }
}
