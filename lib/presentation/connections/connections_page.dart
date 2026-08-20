import 'package:db_explorer_app/presentation/home/placeholder_panel.dart';
import 'package:db_explorer_app/product/router/routes.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Connections management page — Phase 3'te gerçek implementasyon.
class ConnectionsPage extends StatelessWidget {
  const ConnectionsPage({super.key, this.isNew = false});

  final bool isNew;

  @override
  Widget build(BuildContext context) {
    final title = isNew ? 'New Connection' : 'Connections';
    final subtitle = isNew
        ? 'Add a new database connection profile.'
        : 'Manage saved database connection profiles.';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: isNew
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go(AppRoutes.connections),
              )
            : null,
      ),
      body: PlaceholderPanel(
        title: title,
        subtitle: subtitle,
        phaseNumber: 3,
        icon: Icons.storage_outlined,
      ),
    );
  }
}
