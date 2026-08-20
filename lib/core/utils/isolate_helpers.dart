import 'package:flutter/foundation.dart';

/// `compute()` için type-safe wrapper — exception'ı `null`'a çevirir.
///
/// Phase 0'da sadece skeleton; Phase 3+ (MongoDB query execution) ve
/// Phase 7+ (AI inference) gerçek kullanıma girer.
///
/// Type parameter sırası `compute<M, R>` ile uyumlu:
/// - M: message (input) type
/// - R: result (output) type
Future<R?> computeSafe<R, M>(ComputeCallback<M, R> callback, M message) async {
  try {
    return await compute<M, R>(callback, message);
  } catch (_) {
    return null;
  }
}
