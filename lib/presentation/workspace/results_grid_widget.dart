import 'dart:convert';

import 'package:db_explorer_app/core/theme/theme_extensions.dart';
import 'package:db_explorer_app/domain/database/query.dart';
import 'package:db_explorer_app/domain/database/schema.dart';
import 'package:db_explorer_app/presentation/workspace/query_editor_cubit.dart';
import 'package:flutter/material.dart' hide DataRow;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Query result data grid — Phase 4.
///
/// Sorumlulukları:
/// - **State render**: idle / loading / empty / error / data
/// - **Header strip**: row count + execution time + (varsa) totalCount
///   + warnings badge
/// - **Column headers**: tip tahminine göre renklendirilmiş (DataGridPalette)
/// - **Rows**: tip-aware hücre rengi; tap → satır JSON'u clipboard'a kopyala
/// - **Performance**: `ListView.builder` (lazy build); gerçek virtual scroll
///   (ScrollablePositionedList) Phase 8+ optimizasyon
class ResultsGridWidget extends StatelessWidget {
  const ResultsGridWidget({super.key, required this.state});

  final QueryEditorState state;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      QueryEditorState s when s.isExecuting => const _LoadingPanel(),
      QueryEditorState s when s.lastError != null =>
        _ErrorPanel(message: s.lastError!),
      QueryEditorState s when s.lastResult == null => const _IdlePanel(),
      QueryEditorState s when s.lastResult!.isEmpty =>
        _EmptyPanel(result: s.lastResult!),
      QueryEditorState s => _DataPanel(result: s.lastResult!),
    };
  }
}

// ─────────────────────────────────────────────────────────────────────────
// State panels (idle / loading / empty / error)
// ─────────────────────────────────────────────────────────────────────────

class _IdlePanel extends StatelessWidget {
  const _IdlePanel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.play_circle_outline,
            size: 48,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 12),
          Text(
            'Run a query to see results',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Executing query…',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.result});
  final QueryResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        _ResultHeader(result: result),
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.inbox_outlined,
                  size: 48,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 12),
                Text(
                  'Query returned no rows',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Columns: ${result.columns.length}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final errorColor = theme.colorScheme.error;
    return Container(
      color: errorColor.withValues(alpha: 0.08),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: errorColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Query failed',
                style: theme.textTheme.titleSmall?.copyWith(color: errorColor),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: SelectableText(
                message,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  color: errorColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Data panel — header strip + scrollable grid
// ─────────────────────────────────────────────────────────────────────────

class _DataPanel extends StatelessWidget {
  const _DataPanel({required this.result});
  final QueryResult result;

  @override
  Widget build(BuildContext context) {
    final palette = context.dataGrid;
    final inferredColumns = _inferColumns(result);

    return Column(
      children: [
        _ResultHeader(result: result),
        _ColumnHeaderRow(columns: inferredColumns),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: result.rows.length,
            itemBuilder: (context, index) {
              return _DataRow(
                index: index,
                row: result.rows[index],
                columns: inferredColumns,
                palette: palette,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ResultHeader extends StatelessWidget {
  const _ResultHeader({required this.result});
  final QueryResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final countLabel = result.totalCount != null &&
            result.totalCount! > result.rows.length
        ? '${result.rows.length} of ${result.totalCount} rows'
        : '${result.rows.length} ${result.rows.length == 1 ? "row" : "rows"}';

    final timeLabel = '${result.executionTime.inMilliseconds} ms';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      child: Row(
        children: [
          Icon(
            Icons.table_chart_outlined,
            size: 16,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 6),
          Text(
            countLabel,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 12),
          Icon(
            Icons.timer_outlined,
            size: 14,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 4),
          Text(
            timeLabel,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          if (result.hasMore) ...[
            const SizedBox(width: 12),
            _Chip(label: 'more pages', color: theme.colorScheme.primary),
          ],
          const Spacer(),
          if (result.warnings.isNotEmpty)
            _Chip(
              label: '${result.warnings.length} warning(s)',
              color: Colors.amber.shade700,
              icon: Icons.warning_amber_outlined,
            ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color, this.icon});
  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ColumnHeaderRow extends StatelessWidget {
  const _ColumnHeaderRow({required this.columns});
  final List<_InferredColumn> columns;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.dataGrid;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: palette.headerBackground,
      child: Row(
        children: [
          for (final col in columns) ...[
            Expanded(
              child: Text(
                col.name,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: _colorForType(col.type, palette, theme),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (col != columns.last) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  const _DataRow({
    required this.index,
    required this.row,
    required this.columns,
    required this.palette,
  });
  final int index;
  final DataRow row;
  final List<_InferredColumn> columns;
  final DataGridPalette palette;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () => _copyRowToClipboard(context, row),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: index.isOdd ? palette.rowAltBackground : null,
          border: Border(
            bottom: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            for (final col in columns) ...[
              Expanded(
                child: Text(
                  _formatValue(row.values[col.name]),
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: _colorForValue(
                      row.values[col.name],
                      palette,
                      theme,
                    ),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (col != columns.last) const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }
}

Future<void> _copyRowToClipboard(BuildContext context, DataRow row) async {
  await Clipboard.setData(
    ClipboardData(text: jsonEncode(row.values)),
  );
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Row copied to clipboard (JSON)'),
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: 2),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────
// Type inference + color mapping
// ─────────────────────────────────────────────────────────────────────────

class _InferredColumn {
  const _InferredColumn({required this.name, required this.type});
  final String name;
  final String type;
}

List<_InferredColumn> _inferColumns(QueryResult result) {
  // Her kolonun tipini ilk non-null değerden çıkar.
  // Hepsi null ise "string" default'una fallback.
  return result.columns.map((colName) {
    String detectedType = 'string';
    for (final row in result.rows) {
      final v = row.values[colName];
      if (v != null) {
        detectedType = _typeNameOf(v);
        break;
      }
    }
    return _InferredColumn(name: colName, type: detectedType);
  }).toList(growable: false);
}

String _typeNameOf(Object? value) {
  if (value == null) return 'null';
  if (value is bool) return 'bool';
  if (value is num) return 'number';
  if (value is String) return 'string';
  if (value is DateTime) return 'date';
  if (value is List) return 'array';
  if (value is Map) return 'object';
  // ObjectId / custom BSON type: class adından tahmin et
  final typeName = value.runtimeType.toString().toLowerCase();
  if (typeName.contains('objectid') || typeName.contains('oid')) {
    return 'objectid';
  }
  if (typeName.contains('binary') || typeName.contains('byte')) {
    return 'binary';
  }
  return 'object';
}

Color _colorForType(String type, DataGridPalette palette, ThemeData theme) {
  return switch (type) {
    'bool' => palette.booleanTrue,
    'number' => palette.numberForeground,
    'string' => palette.stringForeground,
    'date' => palette.dateForeground,
    'objectid' => palette.objectIdForeground,
    'binary' => palette.binaryForeground,
    _ => theme.colorScheme.onSurface.withValues(alpha: 0.8),
  };
}

Color _colorForValue(
  Object? value,
  DataGridPalette palette,
  ThemeData theme,
) {
  if (value == null) return palette.nullForeground;
  if (value is bool) {
    return value ? palette.booleanTrue : palette.booleanFalse;
  }
  return _colorForType(_typeNameOf(value), palette, theme);
}

String _formatValue(Object? value) {
  if (value == null) return 'null';
  if (value is bool) return value.toString();
  if (value is num) {
    if (value is double && value == value.truncateToDouble()) {
      return value.toInt().toString();
    }
    return value.toString();
  }
  if (value is DateTime) {
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(value);
  }
  if (value is String) {
    return _truncate(value);
  }
  if (value is List || value is Map) {
    return _truncate(jsonEncode(value));
  }
  // ObjectId ve diğer özel tipler
  return _truncate(value.toString());
}

String _truncate(String s, {int maxLen = 200}) {
  return s.length > maxLen ? '${s.substring(0, maxLen)}…' : s;
}
