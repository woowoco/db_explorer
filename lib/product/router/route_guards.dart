import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Route guards — Phase 0'da sadece stub.
///
/// İleride burada:
/// - Auth guard (kullanıcı login değilse /login'e yönlendir)
/// - Connection guard (workspace'e girmek için aktif connection gerekli)
/// - AI guard (ai-assistant'a girmek için AI provider available olmalı)
///
/// Her guard bir redirect callback'i olarak `GoRouter.redirect` zincirinde
/// eklenir. Phase 0'da tüm guards pass-through.
class AppRouteGuards {
  AppRouteGuards._();

  /// Şu an için hiçbir guard yok; tüm route'lara izin ver.
  static String? redirectGuard(
    BuildContext context,
    GoRouterState state,
  ) {
    return null;
  }
}
