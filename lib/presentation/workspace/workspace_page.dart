import 'dart:async';
import 'dart:math';

import 'package:db_explorer_app/core/theme/theme_extensions.dart';
import 'package:db_explorer_app/domain/database/query.dart';
import 'package:db_explorer_app/domain/database/schema.dart';
import 'package:db_explorer_app/presentation/workspace/code_editor_widget.dart';
import 'package:db_explorer_app/presentation/workspace/query_editor_cubit.dart';
import 'package:db_explorer_app/presentation/workspace/results_grid_widget.dart';
import 'package:flutter/material.dart' hide DataRow;
import 'package:flutter_bloc/flutter_bloc.dart';

/// Query workspace — Phase 4.
///
/// Toolbar (language + Run/Stop + history + clear) + code editor + results
/// grid. Her `WorkspacePage` instance'ı kendi `QueryEditorCubit`'ini
/// `BlocProvider` ile scope'lar — adaptive shell'lerdeki birden fazla
/// instance bağımsız çalışır.
///
/// **Mock execute**: Gerçek provider entegrasyonu Phase 8'de. Şimdilik Run
/// tuşu 600ms simulated latency sonrası mock sonuç veya random hata döner.
class WorkspacePage extends StatelessWidget {
  const WorkspacePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => QueryEditorCubit(),
      child: const _WorkspaceView(),
    );
  }
}

class _WorkspaceView extends StatelessWidget {
  const _WorkspaceView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<QueryEditorCubit, QueryEditorState>(
      builder: (context, state) {
        return Column(
          children: [
            const _WorkspaceToolbar(),
            const Divider(height: 1),
            const Expanded(
              flex: 4,
              child: QueryCodeEditor(),
            ),
            const Divider(height: 1),
            Expanded(
              flex: 6,
              child: ResultsGridWidget(state: state),
            ),
          ],
        );
      },
    );
  }
}

class _WorkspaceToolbar extends StatelessWidget {
  const _WorkspaceToolbar();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = context.spacing;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.s12,
        vertical: spacing.s8,
      ),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      child: BlocBuilder<QueryEditorCubit, QueryEditorState>(
        builder: (context, state) {
          return Row(
            children: [
              _LanguageSelector(current: state.language),
              const SizedBox(width: 8),
              _RunButton(state: state),
              const SizedBox(width: 4),
              _ToolbarIconButton(
                icon: Icons.undo,
                tooltip: 'Previous query',
                onPressed: state.canUndoHistory
                    ? () => context.read<QueryEditorCubit>().undoHistory()
                    : null,
              ),
              _ToolbarIconButton(
                icon: Icons.redo,
                tooltip: 'Next query',
                onPressed: state.canRedoHistory
                    ? () => context.read<QueryEditorCubit>().redoHistory()
                    : null,
              ),
              _ToolbarIconButton(
                icon: Icons.delete_outline,
                tooltip: 'Clear editor',
                onPressed: state.text.isEmpty
                    ? null
                    : () => context.read<QueryEditorCubit>().clearEditor(),
              ),
              const Spacer(),
              if (state.isExecuting)
                Row(
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Running…',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                )
              else if (state.lastError != null)
                Text(
                  'Last: failed',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                )
              else if (state.lastResult != null)
                Text(
                  'Last: ${state.lastResult!.rows.length} rows · '
                  '${state.lastResult!.executionTime.inMilliseconds} ms',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _LanguageSelector extends StatelessWidget {
  const _LanguageSelector({required this.current});
  final QueryLanguage current;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopupMenuButton<QueryLanguage>(
      tooltip: 'Query language',
      initialValue: current,
      onSelected: (lang) => context.read<QueryEditorCubit>().setLanguage(lang),
      itemBuilder: (context) => [
        for (final lang in QueryLanguage.values)
          PopupMenuItem(
            value: lang,
            child: Row(
              children: [
                if (lang == current)
                  Icon(Icons.check, size: 16, color: theme.colorScheme.primary)
                else
                  const SizedBox(width: 16),
                const SizedBox(width: 8),
                Text(lang.label),
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              current.label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
    );
  }
}

class _RunButton extends StatelessWidget {
  const _RunButton({required this.state});
  final QueryEditorState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canRun = !state.isExecuting && state.text.trim().isNotEmpty;
    return FilledButton.icon(
      onPressed: canRun ? () => _onRun(context) : null,
      icon: Icon(state.isExecuting ? Icons.stop : Icons.play_arrow, size: 18),
      label: Text(state.isExecuting ? 'Stop' : 'Run'),
      style: FilledButton.styleFrom(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        textStyle: theme.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _onRun(BuildContext context) {
    final cubit = context.read<QueryEditorCubit>();
    cubit.markExecuting();
    // Mock execute — Phase 8'de gerçek provider entegrasyonu.
    // %80 başarı, %20 sentetik hata (random).
    Future<void>.delayed(const Duration(milliseconds: 600), () {
      if (Random().nextDouble() < 0.2) {
        cubit.markFailed(
          'SyntaxError: Unexpected token at position 42\n'
          '    at MongoShellParser.parse (mongo_shell.dart:128)\n'
          '    at QueryEngine.execute (engine.dart:54)',
        );
        return;
      }
      cubit.markCompleted(
        QueryResult(
          columns: const ['_id', 'name', 'age', 'active'],
          rows: List.generate(
            25,
            (i) => DataRow({
              '_id': 'ObjectId(60a7b8${i.toString().padLeft(4, '0')})',
              'name': ['Alice', 'Bob', 'Charlie', 'Diana'][i % 4],
              'age': 20 + (i * 3) % 50,
              'active': i.isEven,
            }),
          ),
          executionTime: Duration(
            milliseconds: 42 + Random().nextInt(120),
          ),
          totalCount: 25,
        ),
      );
    });
  }
}

class _ToolbarIconButton extends StatelessWidget {
  const _ToolbarIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 20),
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    );
  }
}
