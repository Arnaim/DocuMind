import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exceptions.dart';
import '../ai_provider.dart';

/// Base for OpenAI-compatible /chat/completions providers (OpenRouter,
/// Ollama, any custom endpoint). Subclasses only supply identity + defaults.
abstract class OpenAiCompatibleProvider implements AiProvider {
  @override
  Future<List<double>?> embed(String text, AiConfig config) async => null;

  final http.Client client;

  OpenAiCompatibleProvider({http.Client? client})
      : client = client ?? http.Client();

  @override
  Future<AiResponse> complete(AiRequest request, AiConfig config) async {
    final base = config.baseUrl?.trim() ?? defaultBaseUrl();
    final url = base.endsWith('/chat/completions')
        ? base
        : '${base.replaceAll(RegExp(r'/+$'), '')}/chat/completions';

    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (config.apiKey?.isNotEmpty == true) 'Authorization': 'Bearer ${config.apiKey}',
    };

    final body = jsonEncode({
      'model': config.model,
      'messages': [
        {'role': 'system', 'content': request.systemPrompt},
        {'role': 'user', 'content': request.userPrompt},
      ],
      'temperature': request.temperature,
      'max_tokens': request.maxOutputTokens,
      'stream': false,
    });

    try {
      final response = await client
          .post(Uri.parse(url), headers: headers, body: body)
          .timeout(AppConstants.aiRequestTimeout);

      if (response.statusCode != 200) {
        throw httpErrorToAiException(response.statusCode, displayName,
            body: response.body);
      }

      final json = jsonDecode(response.body) as Map<String, Object?>;
      final choices = json['choices'] as List?;
      if (choices == null || choices.isEmpty) {
        throw AiProviderException(
          '$displayName returned no completion.',
          hint: 'The model may be unavailable. Try another model in Settings.',
        );
      }
      final message = (choices.first as Map)['message'] as Map?;
      final text = message?['content'] as String?;
      if (text == null || text.trim().isEmpty) {
        throw AiProviderException(
          '$displayName returned an empty response.',
          hint: 'Try rephrasing, or pick a different model.',
        );
      }
      final usage = json['usage'] as Map?;
      return AiResponse(
        text: text.trim(),
        inputTokens: usage?['prompt_tokens'] as int?,
        outputTokens: usage?['completion_tokens'] as int?,
      );
    } on TimeoutException {
      throw AiProviderException(
        '$displayName did not respond in time.',
        hint: 'Try a shorter question or a smaller document scope.',
      );
    } on http.ClientException catch (e) {
      throw mapAiError(e, providerName: displayName);
    }
  }

  String defaultBaseUrl();
}

/// OpenRouter — one key, hundreds of models, cheap free tier.
class OpenRouterProvider extends OpenAiCompatibleProvider {
  OpenRouterProvider({super.client});

  @override
  String get id => 'openrouter';
  @override
  String get displayName => 'OpenRouter';
  @override
  AiProviderKind get kind => AiProviderKind.cloud;

  @override
  List<String> get availableModels => const [
        'google/gemini-2.0-flash-001',
        'meta-llama/llama-3.3-70b-instruct',
        'anthropic/claude-3.5-haiku',
        'openai/gpt-4o-mini',
        'mistralai/mistral-small-latest',
        'qwen/qwen-2.5-72b-instruct',
      ];

  @override
  bool get isConfigured => true;

  @override
  String statusLabel(AiConfig config) =>
      (config.apiKey == null || config.apiKey!.trim().isEmpty)
          ? 'API key required'
          : 'Ready';

  String get chatEndpoint => 'https://openrouter.ai/api/v1/chat/completions';

  @override
  String defaultBaseUrl() => 'https://openrouter.ai/api/v1';
}

/// Ollama — fully local inference, no cloud, no key. Optional advanced path.
class OllamaProvider extends OpenAiCompatibleProvider {
  OllamaProvider({super.client});

  @override
  String get id => 'ollama';
  @override
  String get displayName => 'Ollama (local)';
  @override
  AiProviderKind get kind => AiProviderKind.local;

  @override
  List<String> get availableModels => const [
        'llama3.2',
        'qwen2.5',
        'gemma2',
        'mistral',
        'phi3.5',
        'nomic-embed-text',
      ];

  @override
  bool get isConfigured => true;

  @override
  String statusLabel(AiConfig config) {
    final base = config.baseUrl?.trim();
    if (base == null || base.isEmpty) {
      return 'Server URL required (e.g. http://192.168.1.20:11434)';
    }
    return 'Ready (device must reach the Ollama host)';
  }

  String get chatEndpoint => 'http://localhost:11434/v1/chat/completions';

  @override
  String defaultBaseUrl() => 'http://localhost:11434/v1';

  /// Ollama-native embeddings endpoint (/api/embeddings), used for local
  /// semantic search. Returns null on any failure so retrieval degrades to
  /// lexical-only instead of erroring.
  @override
  Future<List<double>?> embed(String text, AiConfig config) async {
    final base = config.baseUrl?.trim().replaceAll(RegExp(r'/+$'), '');
    if (base == null || base.isEmpty) return null;
    try {
      final response = await client
          .post(
            Uri.parse('$base/api/embeddings'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'model': 'nomic-embed-text', 'prompt': text}),
          )
          .timeout(AppConstants.aiRequestTimeout);
      if (response.statusCode != 200) return null;
      final json = jsonDecode(response.body) as Map<String, Object?>;
      final values = json['embedding'] as List?;
      if (values == null) return null;
      return values.map((v) => (v as num).toDouble()).toList();
    } catch (_) {
      return null;
    }
  }
}
