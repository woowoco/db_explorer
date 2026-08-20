import 'package:db_explorer_app/domain/database/query.dart';
import 'package:db_explorer_app/domain/database/schema.dart';
import 'package:db_explorer_app/presentation/workspace/query_editor_cubit.dart';
import 'package:db_explorer_app/presentation/workspace/results_grid_widget.dart';
import 'package:flutter/material.dart' hide DataRow;
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

/// ResultsGridWidget state branch'lerinin render testleri.
///
/// Idle / Loading / Empty / Error / Data state'lerinin her birinin beklenen
/// UI element'larını içerdiğini doğrular. Gerçek veri tiplerinin (bool, num,
/// string, vs.) renk ataması için ana akış testlerine güveniyoruz — burada
/// sadece state machine render doğrulanıyor.
void main() {
  group('ResultsGridWidget — state branches', () {
    Widget host(QueryEditorState state) {
      return wrapWithAppTheme(child: ResultsGridWidget(state: state));
    }

    testWidgets('idle state shows hint and play icon', (tester) async {
      const state = QueryEditorState(
        text: '',
        language: QueryLanguage.mongoShell,
        dirty: false,
      );

      await tester.pumpWidget(host(state));

      expect(find.text('Run a query to see results'), findsOneWidget);
      expect(find.byIcon(Icons.play_circle_outline), findsOneWidget);
    });

    testWidgets('loading state shows spinner and progress text',
        (tester) async {
      const state = QueryEditorState(
        text: 'q',
        language: QueryLanguage.mongoShell,
        dirty: true,
        isExecuting: true,
      );

      await tester.pumpWidget(host(state));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Executing query…'), findsOneWidget);
    });

    testWidgets('error state shows error message and icon', (tester) async {
      const state = QueryEditorState(
        text: 'q',
        language: QueryLanguage.mongoShell,
        dirty: true,
        lastError: 'Boom: missing semicolon',
      );

      await tester.pumpWidget(host(state));

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Query failed'), findsOneWidget);
      expect(find.text('Boom: missing semicolon'), findsOneWidget);
    });

    testWidgets('empty result shows column count', (tester) async {
      const state = QueryEditorState(
        text: 'q',
        language: QueryLanguage.mongoShell,
        dirty: false,
        lastResult: QueryResult(
          columns: ['id', 'name'],
          rows: [],
          executionTime: Duration.zero,
        ),
      );

      await tester.pumpWidget(host(state));

      expect(find.text('Query returned no rows'), findsOneWidget);
      expect(find.text('Columns: 2'), findsOneWidget);
    });

    testWidgets('data result shows header strip and rows', (tester) async {
      const state = QueryEditorState(
        text: 'q',
        language: QueryLanguage.mongoShell,
        dirty: false,
        lastResult: QueryResult(
          columns: ['id', 'name', 'active'],
          rows: [
            DataRow({'id': 1, 'name': 'Alice', 'active': true}),
            DataRow({'id': 2, 'name': 'Bob', 'active': false}),
          ],
          executionTime: Duration(milliseconds: 42),
        ),
      );

      await tester.pumpWidget(host(state));

      // Header strip
      expect(find.text('2 rows'), findsOneWidget);
      expect(find.text('42 ms'), findsOneWidget);

      // Column headers
      expect(find.text('id'), findsOneWidget);
      expect(find.text('name'), findsOneWidget);
      expect(find.text('active'), findsOneWidget);

      // Row values
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('true'), findsOneWidget);
      expect(find.text('false'), findsOneWidget);
    });

    testWidgets('data result with warnings shows warning chip', (tester) async {
      const state = QueryEditorState(
        text: 'q',
        language: QueryLanguage.mongoShell,
        dirty: false,
        lastResult: QueryResult(
          columns: ['x'],
          rows: [DataRow({'x': 1})],
          executionTime: Duration(milliseconds: 10),
          warnings: ['Index not used', 'Full collection scan'],
        ),
      );

      await tester.pumpWidget(host(state));

      expect(find.text('2 warning(s)'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_outlined), findsOneWidget);
    });

    testWidgets('data result with hasMore shows more-pages chip',
        (tester) async {
      const state = QueryEditorState(
        text: 'q',
        language: QueryLanguage.mongoShell,
        dirty: false,
        lastResult: QueryResult(
          columns: ['x'],
          rows: [DataRow({'x': 1})],
          executionTime: Duration(milliseconds: 10),
          hasMore: true,
        ),
      );

      await tester.pumpWidget(host(state));

      expect(find.text('more pages'), findsOneWidget);
    });

    testWidgets('data result with totalCount > rows shows "N of M"',
        (tester) async {
      final state = QueryEditorState(
        text: 'q',
        language: QueryLanguage.mongoShell,
        dirty: false,
        lastResult: QueryResult(
          columns: const ['x'],
          rows: List.generate(3, (i) => DataRow({'x': i})),
          executionTime: const Duration(milliseconds: 10),
          totalCount: 100,
        ),
      );

      await tester.pumpWidget(host(state));

      expect(find.text('3 of 100 rows'), findsOneWidget);
    });
  });

  group('ResultsGridWidget — row tap', () {
    testWidgets('tapping a row copies its JSON to clipboard', (tester) async {
      await tester.pumpWidget(
        wrapWithAppTheme(
          child: const ResultsGridWidget(
            state: QueryEditorState(
              text: 'q',
              language: QueryLanguage.mongoShell,
              dirty: false,
              lastResult: QueryResult(
                columns: ['id', 'name'],
                rows: [DataRow({'id': 1, 'name': 'Alice'})],
                executionTime: Duration.zero,
              ),
            ),
          ),
        ),
      );

      // Tap the Alice cell — the InkWell wraps the entire row, so any cell
      // tap triggers the same callback. runAsync lets Clipboard.setData's
      // microtask future complete before the SnackBar is shown.
      await tester.tap(find.text('Alice'));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();

      // SnackBar feedback appears.
      expect(find.text('Row copied to clipboard (JSON)'), findsOneWidget);
    });
  });
}
