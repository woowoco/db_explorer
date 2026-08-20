import 'package:equatable/equatable.dart';

/// Kullanıcının niyeti — raw text + parsed structured intent.
///
/// Phase 0'da sadece rawText tutulur; structured intent parsing
/// (örn. "Find users where age > 30" → {collection: 'users', filter:
/// {age: {'\$gt': 30}}}) ileride eklenebilir.
class UserIntent extends Equatable {
  const UserIntent({required this.rawText, this.structured});

  final String rawText;

  /// Structured intent — şimdilik her zaman null; structured parser
  /// hazır olduğunda parse eder.
  final Map<String, Object?>? structured;

  @override
  List<Object?> get props => [rawText, structured];
}
