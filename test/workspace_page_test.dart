import 'package:db_explorer_app/presentation/workspace/code_editor_widget.dart';
import 'package:db_explorer_app/presentation/workspace/query_editor_cubit.dart';
import 'package:db_explorer_app/presentation/workspace/workspace_page.dart';
import 'package:flutter/material.dart' hide DataRow;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

/// WorkspacePage smoke testleri.
///
/// Gerçek provider entegrasyonu Phase 8'de; burada sadece:
/// - Cubit scope'unun doğru kurulduğu
/// - Run button enable/disable mantığı
/// - Language selector erişilebilirliği
/// doğrulanıyor.
void main() {
  group('WorkspacePage — scaffold', () {
    testWidgets('provides QueryEditorCubit in scope', (tester) async {
      await tester.pumpWidget(
        wrapWithAppTheme(child: const WorkspacePage()),
      );

      // Toolbar + dil seçici + Run button görünür.
      expect(find.byType(WorkspacePage), findsOneWidget);
      expect(find.text('MongoDB Shell'), findsOneWidget);
      expect(find.text('Run'), findsOneWidget);
    });

    testWidgets('Run button is disabled with empty editor', (tester) async {
      await tester.pumpWidget(
        wrapWithAppTheme(child: const WorkspacePage()),
      );

      final runButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Run'),
      );
      expect(runButton.onPressed, isNull);
    });

    testWidgets('Run button enables after typing text', (tester) async {
      await tester.pumpWidget(
        wrapWithAppTheme(child: const WorkspacePage()),
      );

      // Cubit WorkspacePage içindeki BlocProvider'da scope'lu — QueryCodeEditor
      // bu scope'un altındaki ilk widget, onun element'ından read yapabiliriz.
      final innerContext = tester.element(find.byType(QueryCodeEditor));
      innerContext.read<QueryEditorCubit>().updateText('db.users.find()');
      await tester.pump();

      final runButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Run'),
      );
      expect(runButton.onPressed, isNotNull);
    });
  });
}
