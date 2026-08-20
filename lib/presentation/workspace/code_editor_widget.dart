import 'package:db_explorer_app/core/theme/theme_extensions.dart';
import 'package:db_explorer_app/domain/database/query.dart';
import 'package:db_explorer_app/presentation/workspace/query_editor_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:highlight/highlight.dart' show Mode;
import 'package:highlight/languages/javascript.dart';
import 'package:highlight/languages/sql.dart';

/// Query editor wrapper — flutter_code_editor'ı db_explorer'ın design
/// language'ıyla (Poppins + EditorPalette) ve QueryEditorCubit ile
/// entegre eder.
///
/// **Language dispatch:**
/// - `mongoShell` → javascript (close enough — db.collection.method syntax)
/// - `sql` → sql
/// - `redisCmd` → plain text (Phase 6+)
/// - `elasticDsl` → plain text (Phase 6+)
class QueryCodeEditor extends StatefulWidget {
  const QueryCodeEditor({super.key});

  @override
  State<QueryCodeEditor> createState() => _QueryCodeEditorState();
}

class _QueryCodeEditorState extends State<QueryCodeEditor> {
  late final CodeController _controller;

  @override
  void initState() {
    super.initState();
    final initialText = context.read<QueryEditorCubit>().state.text;
    final initialLang = context.read<QueryEditorCubit>().state.language;
    _controller = CodeController(
      text: initialText,
      language: _languageFor(initialLang),
    );
    _controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    final text = _controller.text;
    if (!mounted) return;
    final cubit = context.read<QueryEditorCubit>();
    if (cubit.state.text != text) {
      cubit.updateText(text);
    }
  }

  /// QueryLanguage → highlight Mode eşlemesi.
  Mode? _languageFor(QueryLanguage lang) {
    return switch (lang) {
      QueryLanguage.mongoShell => javascript,
      QueryLanguage.sql => sql,
      QueryLanguage.redisCmd => null,
      QueryLanguage.elasticDsl => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final editorPalette = context.editor;

    return BlocListener<QueryEditorCubit, QueryEditorState>(
      listenWhen: (prev, curr) =>
          prev.text != curr.text && curr.text != _controller.text,
      listener: (context, state) {
        // Cubit'ten external update geldi (history nav, AI suggestion, vs.)
        final selection = _controller.selection;
        _controller.text = state.text;
        // Cursor pozisyonunu koru (mümkünse)
        if (selection.baseOffset <= state.text.length) {
          _controller.selection = selection;
        }
      },
      child: BlocListener<QueryEditorCubit, QueryEditorState>(
        listenWhen: (prev, curr) => prev.language != curr.language,
        listener: (context, state) {
          _controller.language = _languageFor(state.language);
        },
        child: CodeField(
          controller: _controller,
          textStyle: TextStyle(
            fontFamily: 'monospace',
            fontSize: 14,
            color: editorPalette.foreground,
          ),
          background: editorPalette.background,
          gutterStyle: GutterStyle(
            textStyle: TextStyle(
              color: editorPalette.comment,
              fontFamily: 'monospace',
              fontSize: 12,
            ),
            background: editorPalette.background,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: spacing.s12,
            vertical: spacing.s8,
          ),
        ),
      ),
    );
  }
}
