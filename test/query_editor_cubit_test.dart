import 'package:db_explorer_app/domain/database/query.dart';
import 'package:db_explorer_app/domain/database/schema.dart';
import 'package:db_explorer_app/presentation/workspace/query_editor_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

/// QueryEditorCubit unit tests — state machine doğrulaması.
void main() {
  group('QueryEditorCubit — initial state', () {
    test('default is empty mongoShell', () {
      final cubit = QueryEditorCubit();
      expect(cubit.state.text, '');
      expect(cubit.state.language, QueryLanguage.mongoShell);
      expect(cubit.state.dirty, isFalse);
      expect(cubit.state.lastResult, isNull);
      expect(cubit.state.lastError, isNull);
      expect(cubit.state.isExecuting, isFalse);
      expect(cubit.state.history, isEmpty);
      expect(cubit.state.historyCursor, -1);
    });

    test('with initial text + language', () {
      final cubit = QueryEditorCubit(
        initialText: 'db.users.find()',
        language: QueryLanguage.sql,
      );
      expect(cubit.state.text, 'db.users.find()');
      expect(cubit.state.language, QueryLanguage.sql);
      expect(cubit.state.dirty, isFalse);
    });
  });

  group('QueryEditorCubit — text editing', () {
    test('updateText sets dirty=true', () {
      final cubit = QueryEditorCubit();
      cubit.updateText('db.users.find()');
      expect(cubit.state.text, 'db.users.find()');
      expect(cubit.state.dirty, isTrue);
    });

    test('updateText with same text is no-op', () {
      final cubit = QueryEditorCubit();
      cubit.updateText('db.users.find()');
      cubit.updateText('db.users.find()');
      expect(cubit.state.dirty, isTrue);
      expect(cubit.state.text, 'db.users.find()');
    });

    test('setLanguage changes language and marks dirty', () {
      final cubit = QueryEditorCubit();
      cubit.setLanguage(QueryLanguage.sql);
      expect(cubit.state.language, QueryLanguage.sql);
      expect(cubit.state.dirty, isTrue);
    });
  });

  group('QueryEditorCubit — execution lifecycle', () {
    test('markExecuting clears error', () {
      final cubit = QueryEditorCubit();
      cubit.markFailed('boom');
      expect(cubit.state.lastError, 'boom');

      cubit.markExecuting();
      expect(cubit.state.isExecuting, isTrue);
      expect(cubit.state.lastError, isNull);
    });

    test('markCompleted sets result and adds to history', () {
      final cubit = QueryEditorCubit();
      cubit.updateText('db.users.find()');

      const result = QueryResult(
        columns: ['doc'],
        rows: [DataRow({'doc': 'test'})],
        executionTime: Duration(milliseconds: 10),
      );

      cubit.markCompleted(result);

      expect(cubit.state.lastResult, same(result));
      expect(cubit.state.isExecuting, isFalse);
      expect(cubit.state.dirty, isFalse);
      expect(cubit.state.history.length, 1);
      expect(cubit.state.history.first.text, 'db.users.find()');
      expect(cubit.state.historyCursor, -1);
    });

    test('markFailed sets error and clears result', () {
      final cubit = QueryEditorCubit();
      cubit.markCompleted(const QueryResult(
        columns: ['x'],
        rows: [],
        executionTime: Duration.zero,
      ));
      cubit.markFailed('syntax error');

      expect(cubit.state.lastResult, isNull);
      expect(cubit.state.lastError, 'syntax error');
      expect(cubit.state.isExecuting, isFalse);
    });
  });

  group('QueryEditorCubit — history navigation', () {
    const emptyResult = QueryResult(
      columns: ['x'],
      rows: [],
      executionTime: Duration.zero,
    );

    test('undoHistory moves forward in history', () {
      final cubit = QueryEditorCubit();
      cubit.updateText('q1');
      cubit.markCompleted(emptyResult);
      cubit.updateText('q2');
      cubit.markCompleted(emptyResult);

      expect(cubit.state.history.length, 2);
      expect(cubit.state.canUndoHistory, isTrue);

      cubit.undoHistory();
      expect(cubit.state.text, 'q2');
      expect(cubit.state.historyCursor, 0);

      cubit.undoHistory();
      expect(cubit.state.text, 'q1');
      expect(cubit.state.historyCursor, 1);

      expect(cubit.state.canUndoHistory, isFalse);
    });

    test('redoHistory moves back toward edit buffer', () {
      final cubit = QueryEditorCubit();
      cubit.updateText('q1');
      cubit.markCompleted(emptyResult);
      cubit.updateText('q2');
      cubit.markCompleted(emptyResult);
      cubit.undoHistory();
      cubit.undoHistory();

      cubit.redoHistory();
      expect(cubit.state.text, 'q2');
      expect(cubit.state.historyCursor, 0);

      cubit.redoHistory();
      expect(cubit.state.historyCursor, -1);
    });

    test('history caps at 50 entries (FIFO)', () {
      final cubit = QueryEditorCubit();
      for (var i = 0; i < 55; i++) {
        cubit.updateText('q$i');
        cubit.markCompleted(emptyResult);
      }
      expect(cubit.state.history.length, 50);
      expect(cubit.state.history.first.text, 'q54');
    });
  });

  group('QueryEditorCubit — AI copilot toggle', () {
    test('toggleAiCopilot flips flag', () {
      final cubit = QueryEditorCubit();
      expect(cubit.state.aiCopilotEnabled, isFalse);
      cubit.toggleAiCopilot();
      expect(cubit.state.aiCopilotEnabled, isTrue);
      cubit.toggleAiCopilot();
      expect(cubit.state.aiCopilotEnabled, isFalse);
    });
  });

  group('QueryEditorCubit — clearEditor', () {
    test('clears text but preserves history', () {
      final cubit = QueryEditorCubit();
      cubit.updateText('q1');
      cubit.markCompleted(const QueryResult(
        columns: ['x'],
        rows: [],
        executionTime: Duration.zero,
      ));
      cubit.markFailed('boom');

      cubit.clearEditor();
      expect(cubit.state.text, '');
      expect(cubit.state.dirty, isFalse);
      expect(cubit.state.lastResult, isNull);
      expect(cubit.state.lastError, isNull);
      expect(cubit.state.history.length, 1);
    });
  });
}