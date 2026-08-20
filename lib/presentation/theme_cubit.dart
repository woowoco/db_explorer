import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// db_explorer_app theme cubit.
///
/// F_AISUBCRIBE'in `ThemeCubit`'inden adapte edildi (5 satırlık orijinal).
class ThemeCubit extends Cubit<ThemeMode> {
  ThemeCubit() : super(ThemeMode.system);

  void setThemeMode(ThemeMode mode) => emit(mode);

  void toggle() {
    final next = switch (state) {
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
      ThemeMode.system => ThemeMode.light,
    };
    emit(next);
  }
}
