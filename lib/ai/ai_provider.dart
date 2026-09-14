import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exceptions.dart';

/// What the AI is being asked to do; drives prompt selection downstream.
enum AiTask {
  questionAnswering,
  summarization,
  study,
  comparison,
  extraction,
}

/// Where a provider lives — affects error messages when offline.
enum AiProviderKind { cloud, local }

/// Provider + model selection, persisted in settings.
class AiConfig {
  final String providerId; // gemini | openrouter | ollama | custom-openai
  final String model;
  final String? apiKey;
  final String? baseUrl; // for Ollama / custom OpenAI-compatible endpoints

  const AiConfig({
    required this.providerId,
    required this.model,
    this.apiKey,
    this.baseUrl,
  });

  AiConfig copyWith({String? providerId, String? model, String? apiKey, String? baseUrl}) =>
      AiConfig(
        providerId: providerId ?? this.providerId,
        model: model ?? this.model,
        apiKey: apiKey ?? this.apiKey,
        baseUrl: baseUrl ?? this.baseUrl,
      );
}

/// A chat-style request with grounded context.
class AiRequest {
  final String systemPrompt;
  final String userPrompt;
  final double temperature;
  final int maxOutputTokens;

  const AiRequest({
    required this.systemPrompt,
    required this.userPrompt,
    this.temperature = AppConstants.aiDefaultTemperature,
    this.maxOutputTokens = AppConstants.aiMaxOutputTokens,
  });
}

/// The model's reply.
class AiResponse {
  final String text;
  final int? inputTokens;
  final int? outputTokens;

  const AiResponse({required this.text, this.inputTokens, this.outputTokens});
}

/// Abstraction over LLM vendors. The RAG pipeline depends on this interface
/// only — swapping Gemini for OpenRouter/Ollama changes nothing upstream.
abstract class AiProvider {
  String get id;
  String get displayName;
  AiProviderKind get kind;

  /// Models offered in the settings picker.
  List<String> get availableModels;

  /// True when the stored configuration is complete enough to try a call.
  bool get isConfigured;

  /// Sends [request] and returns the completion. Implementations must map all
  /// failure modes (offline, timeout, quota, bad key, malformed response) to
  /// [AiProviderException] with user-actionable messages.
  Future<AiResponse> complete(AiRequest request, AiConfig config);

  /// Optional embedding support (semantic search). Returns null when the
  /// provider cannot embed.
  Future<List<double>?> embed(String text, AiConfig config) async => null;

  /// One-line status for the settings page ("Ready", "API key missing", …).
  String statusLabel(AiConfig config);
}

/// Maps HTTP/status/transport failures to actionable AI exceptions.
AiProviderException mapAiError(Object error, {required String providerName}) {
  if (error is AiProviderException) return error;

  final s = error.toString();
  if (s.contains('SocketException') ||
      s.contains('Failed host lookup') ||
      s.contains('Network is unreachable')) {
    return AiProviderException(
      'No internet connection while contacting $providerName.',
      hint: 'Check connectivity and retry. Your documents and local search work offline.',
    );
  }
  return AiProviderException(
    'Could not reach $providerName.',
    hint: 'The service may be down or unreachable. Try again in a moment.',
    cause: error,
  );
}

/// Shared helper: decode a JSON HTTP response and throw descriptive errors.
AiProviderException httpErrorToAiException(int status, String providerName,
    {String? body}) {
  final truncated = (body ?? '').length > 300 ? '${(body ?? '').substring(0, 300)}…' : (body ?? '');
  return switch (status) {
    401 || 403 => AiProviderException(
        '$providerName rejected the API key.',
        hint: 'Open Settings → AI Provider and verify the key has generation access.',
        statusCode: status,
      ),
    429 => AiProviderException(
        '$providerName rate limit or free-tier quota reached.',
        hint: 'Wait a little and try again, or switch models in Settings.',
        statusCode: status,
      ),
    408 => AiProviderException(
        '$providerName took too long to respond.',
        hint: 'Try a shorter question, or fewer documents in scope.',
        statusCode: status,
      ),
    >= 500 => AiProviderException(
        '$providerName had a server error ($status).',
        hint: 'This is temporary — retry shortly.',
        statusCode: status,
      ),
    _ => AiProviderException(
        '$providerName returned an unexpected response ($status).',
        hint: truncated.isEmpty ? null : 'Details: $truncated',
        statusCode: status,
      ),
  };
}
