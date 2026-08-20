import 'package:db_explorer_app/core/theme/theme_extensions.dart';
import 'package:db_explorer_app/infrastructure/ai_providers/ai_prompt_builder.dart';
import 'package:db_explorer_app/infrastructure/ai_providers/disabled.dart';
import 'package:db_explorer_app/infrastructure/registry/ai_provider_registry.dart';
import 'package:db_explorer_app/infrastructure/storage/settings.dart';
import 'package:db_explorer_app/presentation/ai_cubit.dart';
import 'package:db_explorer_app/presentation/app_cubit.dart';
import 'package:db_explorer_app/presentation/theme_cubit.dart';
import 'package:db_explorer_app/product/providers_registry/real_ai_factories.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

/// Settings page — Phase 8.
///
/// Sections:
/// 1. Appearance (theme mode)
/// 2. AI Provider (mode picker + per-mode config + sensitive patterns)
/// 3. About (version)
///
/// AI mode değiştiğinde provider registry yeniden kurulur
/// (`RealAiProviderFactory` + `DisabledProvider` fallback) ve AiCubit
/// refresh edilir. Sensitive pattern listesi de `AiPromptBuilder`'a
/// push edilir.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _localPathCtrl;
  late final TextEditingController _ollamaEndpointCtrl;
  late final TextEditingController _ollamaModelCtrl;
  late final TextEditingController _ollamaBearerCtrl;
  late final TextEditingController _openaiEndpointCtrl;
  late final TextEditingController _openaiModelCtrl;
  late final TextEditingController _openaiApiKeyCtrl;
  late final TextEditingController _sensitiveCtrl;

  @override
  void initState() {
    super.initState();
    final s = context.read<AppCubit>().state;
    _localPathCtrl = TextEditingController(text: s.aiLocalModelPath ?? '');
    _ollamaEndpointCtrl =
        TextEditingController(text: s.aiOllamaEndpoint ?? '');
    _ollamaModelCtrl = TextEditingController(text: s.aiOllamaModel ?? '');
    _ollamaBearerCtrl =
        TextEditingController(text: s.aiOllamaBearerToken ?? '');
    _openaiEndpointCtrl =
        TextEditingController(text: s.aiOpenaiEndpoint ?? '');
    _openaiModelCtrl = TextEditingController(text: s.aiOpenaiModel ?? '');
    _openaiApiKeyCtrl = TextEditingController(text: s.aiOpenaiApiKey ?? '');
    _sensitiveCtrl = TextEditingController(
      text: s.sensitiveFieldPatterns.join('\n'),
    );
  }

  @override
  void dispose() {
    _localPathCtrl.dispose();
    _ollamaEndpointCtrl.dispose();
    _ollamaModelCtrl.dispose();
    _ollamaBearerCtrl.dispose();
    _openaiEndpointCtrl.dispose();
    _openaiModelCtrl.dispose();
    _openaiApiKeyCtrl.dispose();
    _sensitiveCtrl.dispose();
    super.dispose();
  }

  /// AI mode değişti → registry rebuild + sensitive pattern re-apply.
  void _onModeChanged(AiMode mode) async {
    final getIt = GetIt.instance;
    final settings = getIt<AppSettings>();
    final cubit = context.read<AppCubit>();
    await cubit.setAiMode(mode);
    // Registry'yi yeniden kur (Phase 8.2 wiring).
    final registry = getIt<AiProviderRegistry>();
    registry.clear();
    registry.register(const DisabledProvider()); // fallback
    final selected = RealAiProviderFactory(settings).buildFromSettings();
    if (selected != null) registry.register(selected);
    applySensitiveFieldPatterns(settings);
    // AiCubit yeni default provider'ı probe etsin.
    if (!mounted) return;
    await context.read<AiCubit>().refresh(registry);
  }

  /// Sensitive patterns multiline textarea → AppCubit → AppPromptBuilder.
  void _onSensitiveChanged(String value) async {
    final getIt = GetIt.instance;
    final cubit = context.read<AppCubit>();
    final settings = getIt<AppSettings>();
    final lines = value
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    await cubit.setSensitiveFieldPatterns(lines);
    applySensitiveFieldPatterns(settings);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = context.spacing;
    final radius = context.radius;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: BlocBuilder<AppCubit, AppState>(
        builder: (context, state) {
          return ListView(
            padding: EdgeInsets.all(spacing.s16),
            children: [
              // ============ Appearance ============
              const _SectionHeader(title: 'Appearance'),
              BlocBuilder<ThemeCubit, ThemeMode>(
                builder: (context, mode) {
                  return Card(
                    child: RadioGroup<ThemeMode>(
                      groupValue: mode,
                      onChanged: (v) {
                        if (v != null) {
                          context.read<ThemeCubit>().setThemeMode(v);
                        }
                      },
                      child: const Column(
                        children: [
                          ListTile(
                            title: Text('System'),
                            leading: Radio<ThemeMode>(
                              value: ThemeMode.system,
                            ),
                          ),
                          ListTile(
                            title: Text('Light'),
                            leading: Radio<ThemeMode>(
                              value: ThemeMode.light,
                            ),
                          ),
                          ListTile(
                            title: Text('Dark'),
                            leading: Radio<ThemeMode>(
                              value: ThemeMode.dark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              SizedBox(height: spacing.s24),

              // ============ AI Provider ============
              const _SectionHeader(title: 'AI Provider'),
              Card(
                child: Column(
                  children: AiMode.values.map((mode) {
                    return RadioListTile<AiMode>(
                      title: Text(mode.label),
                      value: mode,
                      groupValue: state.aiMode,
                      onChanged: (v) {
                        if (v != null) _onModeChanged(v);
                      },
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(radius.r8),
                      ),
                    );
                  }).toList(),
                ),
              ),
              SizedBox(height: spacing.s16),

              // Mode-specific config cards
              if (state.aiMode == AiMode.local) _LocalLlamaConfigCard(state: state, pathCtrl: _localPathCtrl),
              if (state.aiMode == AiMode.ollamaRemote) _OllamaConfigCard(state: state, endpointCtrl: _ollamaEndpointCtrl, modelCtrl: _ollamaModelCtrl, bearerCtrl: _ollamaBearerCtrl),
              if (state.aiMode == AiMode.openaiCompatible) _OpenAiConfigCard(state: state, endpointCtrl: _openaiEndpointCtrl, modelCtrl: _openaiModelCtrl, apiKeyCtrl: _openaiApiKeyCtrl),
              if (state.aiMode == AiMode.disabled) Padding(
                padding: EdgeInsets.symmetric(vertical: spacing.s8),
                child: Text(
                  'AI is disabled. Pick a provider above to enable.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
              SizedBox(height: spacing.s24),

              // ============ Sensitive patterns ============
              const _SectionHeader(title: 'Sensitive field patterns (regex)'),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(spacing.s16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Her satır bir RegExp pattern. Eşleşen değerler '
                        'AI\'a gönderilmeden önce [REDACTED] ile maskelenir.\n'
                        'Örnek: \\d{4}-\\d{4}-\\d{4}-\\d{4} (kredi kartı)',
                        style: theme.textTheme.bodySmall,
                      ),
                      SizedBox(height: spacing.s8),
                      TextField(
                        controller: _sensitiveCtrl,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: r'\d{4}-\d{4}-\d{4}-\d{4}',
                        ),
                        onChanged: _onSensitiveChanged,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: spacing.s24),

              // ============ About ============
              const _SectionHeader(title: 'About'),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('db_explorer_app'),
                  subtitle: Text(
                    'Phase 8 release prep • ${state.buildVersion}',
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// ============ AI config sub-cards ============

class _LocalLlamaConfigCard extends StatelessWidget {
  const _LocalLlamaConfigCard({required this.state, required this.pathCtrl});
  final AppState state;
  final TextEditingController pathCtrl;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AppCubit>();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Local llama.cpp configuration'),
            const SizedBox(height: 12),
            TextField(
              controller: pathCtrl,
              decoration: const InputDecoration(
                labelText: 'GGUF model path',
                hintText: '/models/qwen2.5-coder-3b-q4_k_m.gguf',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (v) => cubit.setAiLocalModelPath(v.trim()),
            ),
            const SizedBox(height: 12),
            _NumberField(
              label: 'Context size (tokens)',
              initial: state.aiLocalContextSize,
              onSubmit: cubit.setAiLocalContextSize,
            ),
            const SizedBox(height: 12),
            _NumberField(
              label: 'GPU offload layers (0 = CPU-only)',
              initial: state.aiLocalNGpuLayers,
              onSubmit: cubit.setAiLocalNGpuLayers,
            ),
            const SizedBox(height: 12),
            _DecimalField(
              label: 'Temperature',
              initial: state.aiLocalTemperature,
              onSubmit: cubit.setAiLocalTemperature,
            ),
            const SizedBox(height: 12),
            _NumberField(
              label: 'Max tokens',
              initial: state.aiLocalMaxTokens,
              onSubmit: cubit.setAiLocalMaxTokens,
            ),
          ],
        ),
      ),
    );
  }
}

class _OllamaConfigCard extends StatelessWidget {
  const _OllamaConfigCard({
    required this.state,
    required this.endpointCtrl,
    required this.modelCtrl,
    required this.bearerCtrl,
  });
  final AppState state;
  final TextEditingController endpointCtrl;
  final TextEditingController modelCtrl;
  final TextEditingController bearerCtrl;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AppCubit>();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ollama remote server'),
            const SizedBox(height: 12),
            TextField(
              controller: endpointCtrl,
              decoration: const InputDecoration(
                labelText: 'Endpoint URL',
                hintText: 'http://localhost:11434',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (v) => cubit.setAiOllamaEndpoint(v.trim()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: modelCtrl,
              decoration: const InputDecoration(
                labelText: 'Model name',
                hintText: 'qwen2.5-coder:3b',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (v) => cubit.setAiOllamaModel(v.trim()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: bearerCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Bearer token (optional)',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (v) => cubit.setAiOllamaBearerToken(v.trim()),
            ),
            const SizedBox(height: 12),
            _DecimalField(
              label: 'Temperature',
              initial: state.aiOllamaTemperature,
              onSubmit: cubit.setAiOllamaTemperature,
            ),
            const SizedBox(height: 12),
            _NumberField(
              label: 'Timeout (seconds)',
              initial: state.aiOllamaTimeoutSeconds,
              onSubmit: cubit.setAiOllamaTimeoutSeconds,
            ),
          ],
        ),
      ),
    );
  }
}

class _OpenAiConfigCard extends StatelessWidget {
  const _OpenAiConfigCard({
    required this.state,
    required this.endpointCtrl,
    required this.modelCtrl,
    required this.apiKeyCtrl,
  });
  final AppState state;
  final TextEditingController endpointCtrl;
  final TextEditingController modelCtrl;
  final TextEditingController apiKeyCtrl;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AppCubit>();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('OpenAI-compatible API'),
            const SizedBox(height: 12),
            TextField(
              controller: endpointCtrl,
              decoration: const InputDecoration(
                labelText: 'Endpoint URL',
                hintText: 'https://api.openai.com/v1',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (v) => cubit.setAiOpenaiEndpoint(v.trim()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: modelCtrl,
              decoration: const InputDecoration(
                labelText: 'Model name',
                hintText: 'gpt-4o-mini',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (v) => cubit.setAiOpenaiModel(v.trim()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: apiKeyCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'API key',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (v) => cubit.setAiOpenaiApiKey(v.trim()),
            ),
            const SizedBox(height: 12),
            _DecimalField(
              label: 'Temperature',
              initial: state.aiOpenaiTemperature,
              onSubmit: cubit.setAiOpenaiTemperature,
            ),
            const SizedBox(height: 12),
            _NumberField(
              label: 'Max tokens',
              initial: state.aiOpenaiMaxTokens,
              onSubmit: cubit.setAiOpenaiMaxTokens,
            ),
            const SizedBox(height: 12),
            _NumberField(
              label: 'Timeout (seconds)',
              initial: state.aiOpenaiTimeoutSeconds,
              onSubmit: cubit.setAiOpenaiTimeoutSeconds,
            ),
          ],
        ),
      ),
    );
  }
}

/// Integer text field.
class _NumberField extends StatefulWidget {
  const _NumberField({
    required this.label,
    required this.initial,
    required this.onSubmit,
  });
  final String label;
  final int initial;
  final Future<void> Function(int) onSubmit;

  @override
  State<_NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<_NumberField> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initial.toString());

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: widget.label,
        border: const OutlineInputBorder(),
      ),
      onSubmitted: (v) {
        final parsed = int.tryParse(v.trim());
        if (parsed != null) widget.onSubmit(parsed);
      },
    );
  }
}

/// Decimal (double) text field.
class _DecimalField extends StatefulWidget {
  const _DecimalField({
    required this.label,
    required this.initial,
    required this.onSubmit,
  });
  final String label;
  final double initial;
  final Future<void> Function(double) onSubmit;

  @override
  State<_DecimalField> createState() => _DecimalFieldState();
}

class _DecimalFieldState extends State<_DecimalField> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initial.toStringAsFixed(2));

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: widget.label,
        border: const OutlineInputBorder(),
      ),
      onSubmitted: (v) {
        final parsed = double.tryParse(v.trim());
        if (parsed != null) widget.onSubmit(parsed);
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = context.spacing;
    return Padding(
      padding: EdgeInsets.only(
        left: spacing.s4,
        bottom: spacing.s8,
      ),
      child: Text(
        title,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.hintColor,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
