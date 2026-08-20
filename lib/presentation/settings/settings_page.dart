import 'package:db_explorer_app/core/theme/theme_extensions.dart';
import 'package:db_explorer_app/infrastructure/storage/settings.dart';
import 'package:db_explorer_app/presentation/theme_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Settings page — Phase 0'da theme toggle + AI mode toggle çalışır halde.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = context.spacing;
    final radius = context.radius;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: EdgeInsets.all(spacing.s16),
        children: [
          const _SectionHeader(title: 'Appearance'),
          BlocBuilder<ThemeCubit, ThemeMode>(
            builder: (context, mode) {
              return Card(
                child: RadioGroup<ThemeMode>(
                  groupValue: mode,
                  onChanged: (v) {
                    if (v != null) {
                      context.read<ThemeCubit>().setThemeMode(v);
                    }
                  },
                  child: const Column(
                    children: [
                      ListTile(
                        title: Text('System'),
                        leading: Radio<ThemeMode>(value: ThemeMode.system),
                      ),
                      ListTile(
                        title: Text('Light'),
                        leading: Radio<ThemeMode>(value: ThemeMode.light),
                      ),
                      ListTile(
                        title: Text('Dark'),
                        leading: Radio<ThemeMode>(value: ThemeMode.dark),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          SizedBox(height: spacing.s24),
          const _SectionHeader(title: 'AI Mode (Phase 7+)'),
          Card(
            child: Padding(
              padding: EdgeInsets.all(spacing.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI provider seçimi — Phase 7\'de gerçek binding',
                    style: theme.textTheme.bodySmall,
                  ),
                  SizedBox(height: spacing.s8),
                  Wrap(
                    spacing: spacing.s8,
                    children: AiMode.values.map((mode) {
                      return Chip(
                        label: Text(mode.name),
                        backgroundColor: theme.dividerColor.withValues(
                          alpha: 0.2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(radius.r8),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: spacing.s24),
          const _SectionHeader(title: 'About'),
          const Card(
            child: ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('db_explorer_app'),
              subtitle: Text('Phase 0 skeleton • v0.1.0+1'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = context.spacing;
    return Padding(
      padding: EdgeInsets.only(
        left: spacing.s4,
        bottom: spacing.s8,
      ),
      child: Text(
        title,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.hintColor,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
