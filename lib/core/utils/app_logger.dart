import 'package:logger/logger.dart';

/// db_explorer_app logger helper'ı.
///
/// F_AISUBCRIBE'in `lib/core/logger/` standardı sadeleştirildi:
/// - Tek global [Logger] instance (PrettyPrinter, debug only).
/// - `getLogger(String name)` ile modül-bazlı etiketli sub-logger.
Logger getLogger([String name = 'app']) {
  return Logger(
    printer: SimplePrinter(colors: false),
    level: Level.debug,
  );
}
