/// Route path sabitleri.
///
/// db_explorer_app navigation yapısı:
/// - `/` (home): AdaptiveLayoutBuilder switch → 3-panel desktop veya
///   bottom-nav mobile
/// - `/connections` (connections management)
/// - `/workspace` (active query workspace)
/// - `/ai-assistant` (AI Query Copilot panel)
/// - `/settings` (theme + AI config)
class AppRoutes {
  AppRoutes._();

  static const String home = '/';
  static const String connections = '/connections';
  static const String connectionsNew = '/connections/new';
  static const String workspace = '/workspace';
  static const String aiAssistant = '/ai-assistant';
  static const String settings = '/settings';

  /// Bottom nav / sidebar için kullanılan primary destination'lar.
  static const List<String> primaryDestinations = [
    workspace,
    connections,
    aiAssistant,
    settings,
  ];

  static String labelFor(String path) => switch (path) {
    home => 'Home',
    connections => 'Connections',
    connectionsNew => 'New Connection',
    workspace => 'Workspace',
    aiAssistant => 'AI Assistant',
    settings => 'Settings',
    _ => path,
  };
}
