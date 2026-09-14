import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../ai/ai_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../state/library_provider.dart';
import '../../state/settings_provider.dart';
import '../widgets/decorations.dart';

/// Settings: AI provider configuration, appearance, privacy explainer and
/// maintenance actions. Everything local; nothing leaves the device except
/// the retrieval context sent to the chosen AI provider.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _apiKeyController = TextEditingController();
  final _baseUrlController = TextEditingController();

  @override
  void dispose() {
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final config = settings.aiConfig;

    // Keep controllers in sync when switching providers.
    if (_apiKeyController.text != (config.apiKey ?? '') &&
        (!_apiKeyController.text.isNotEmpty || config.apiKey != null)) {
      _apiKeyController.text = config.apiKey ?? '';
    }
    _baseUrlController.text = config.baseUrl ?? '';

    final c = context.docColors;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _SectionBadge(
            icon: Icons.smart_toy_rounded,
            label: 'AI',
            color: c.lavender,
            background: c.lavenderSoft,
          ),
          Card(
            child: Column(
              children: [
                RadioListTile<String>(
                  value: 'gemini',
                  groupValue: config.providerId,
                  onChanged: (v) => _switchProvider(context, v),
                  title: const Text('Google Gemini'),
                  subtitle: const Text('Free API tier · requires key'),
                ),
                RadioListTile<String>(
                  value: 'openrouter',
                  groupValue: config.providerId,
                  onChanged: (v) => _switchProvider(context, v),
                  title: const Text('OpenRouter'),
                  subtitle: const Text('Many models behind one key'),
                ),
                RadioListTile<String>(
                  value: 'ollama',
                  groupValue: config.providerId,
                  onChanged: (v) => _switchProvider(context, v),
                  title: const Text('Ollama (local)'),
                  subtitle: const Text('Fully offline · advanced setup'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: config.model,
                  decoration: const InputDecoration(labelText: 'Model'),
                  items: _modelsFor(config.providerId)
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (m) {
                    if (m != null) {
                      settings.updateAiConfig(config.copyWith(model: m));
                    }
                  },
                ),
                const SizedBox(height: 10),
                if (config.providerId != 'ollama')
                  TextField(
                    controller: _apiKeyController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'API key (stored on this device only)',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.save_outlined),
                        onPressed: () {
                          settings.updateAiConfig(
                              config.copyWith(apiKey: _apiKeyController.text.trim()));
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text('API key saved locally.')));
                        },
                      ),
                    ),
                  ),
                if (config.providerId == 'ollama')
                  TextField(
                    controller: _baseUrlController,
                    decoration: const InputDecoration(
                      labelText: 'Ollama server URL (e.g. http://192.168.1.20:11434)',
                    ),
                    onSubmitted: (v) {
                      settings.updateAiConfig(config.copyWith(baseUrl: v.trim()));
                    },
                  ),
              ],
            ),
          ),
          _SectionBadge(
            icon: Icons.palette_rounded,
            label: 'Appearance',
            color: c.pink,
            background: c.pinkSoft,
          ),
          Card(
            child: Column(
              children: [
                for (final mode in ThemeModeSetting.values)
                  RadioListTile<ThemeModeSetting>(
                    value: mode,
                    groupValue: settings.themeMode,
                    onChanged: (m) {
                      if (m != null) settings.setThemeMode(m);
                    },
                    title: Text(switch (mode) {
                      ThemeModeSetting.system => 'Follow system',
                      ThemeModeSetting.light => 'Light',
                      ThemeModeSetting.dark => 'Dark',
                    }),
                  ),
              ],
            ),
          ),
          _SectionBadge(
            icon: Icons.construction_rounded,
            label: 'Library',
            color: c.mint,
            background: c.mintSoft,
          ),
          Card(
            child: ListTile(
              leading: IconBadge(
                icon: Icons.graphic_eq_rounded,
                color: c.mint,
                background: c.mintSoft,
              ),
              title: const Text('Rebuild semantic index'),
              subtitle:
                  const Text('Re-embed all documents with the current provider'),
              onTap: () async {
                final lib = context.read<LibraryProvider>();
                await lib.reindexEmbeddings();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Semantic index rebuilt.')),
                  );
                }
              },
            ),
          ),
          _SectionBadge(
            icon: Icons.shield_rounded,
            label: 'Data & Privacy',
            color: c.coral,
            background: c.coralSoft,
          ),
          _PrivacyCard(),
        ],
      ),
    );
  }

  List<String> _modelsFor(String providerId) {
    return switch (providerId) {
      'openrouter' => const [
          'google/gemini-2.0-flash-001',
          'meta-llama/llama-3.3-70b-instruct',
          'anthropic/claude-3.5-haiku',
          'openai/gpt-4o-mini',
          'mistralai/mistral-small-latest',
          'qwen/qwen-2.5-72b-instruct',
        ],
      'ollama' => const [
          'llama3.2',
          'qwen2.5',
          'gemma2',
          'mistral',
          'phi3.5',
        ],
      _ => const [
          'gemini-2.0-flash',
          'gemini-2.0-flash-lite',
          'gemini-1.5-flash',
          'gemini-1.5-flash-8b',
          'gemini-1.5-pro',
        ],
    };
  }

  void _switchProvider(BuildContext context, String? providerId) {
    if (providerId == null) return;
    final settings = context.read<SettingsProvider>();
    final model = switch (providerId) {
      'openrouter' => 'google/gemini-2.0-flash-001',
      'ollama' => 'llama3.2',
      _ => 'gemini-2.0-flash',
    };
    settings.updateAiConfig(AiConfig(
      providerId: providerId,
      model: model,
      apiKey: settings.aiConfig.apiKey,
      baseUrl: settings.aiConfig.baseUrl,
    ));
  }
}

/// Settings section header with a colored icon badge.
class _SectionBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color background;

  const _SectionBadge({
    required this.icon,
    required this.label,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
      child: Row(
        children: [
          IconBadge(icon: icon, color: color, background: background, size: 17),
          const SizedBox(width: 10),
          Text(label, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.docColors;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.shield_rounded, color: c.coral),
              const SizedBox(width: 8),
              Text('Where your data lives', style: theme.textTheme.titleSmall),
            ]),
            const SizedBox(height: 10),
            const Text(
              '• Documents are copied into the app\'s private storage on this device; the original stays wherever you imported it from.\n'
              '• Extracted text, the search index and metadata live in a local SQLite database — never uploaded.\n'
              '• Conversations are stored locally and can be deleted at any time.\n\n'
              'When you ask the AI a question:\n'
              '• Your question and the few most relevant retrieved passages are sent to the active AI provider.\n'
              '• Whole documents are never uploaded; only the context needed to answer.\n'
              '• Embeddings and vector search are computed on-device.\n\n'
              'To stop sharing any text with a cloud provider, switch to Ollama (local) or simply don\'t ask new questions while offline.',
              style: TextStyle(height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}
