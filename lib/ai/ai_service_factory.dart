import '../data/datasources/library_datasource.dart';
import 'ai_provider.dart';
import 'embedding_service.dart';
import 'providers/gemini_provider.dart';
import 'providers/openrouter_provider.dart';
import 'rag_service.dart';

/// Builds the active AI stack from an [AiConfig]. This is the single place
/// where a provider id becomes a concrete implementation — the rest of the
/// app only ever sees [AiProvider] and [RagService].
class AiServiceFactory {
  final LibraryDatasource _datasource;

  AiServiceFactory(this._datasource);

  AiProvider providerFor(AiConfig config) => switch (config.providerId) {
        'openrouter' => OpenRouterProvider(),
        'ollama' => OllamaProvider(),
        _ => GeminiProvider(),
      };

  /// Builds a RAG service. Returns null when embeddings can't be used (no
  /// key / local provider without an embed model); lexical FTS still works.
  RagService? createRagService(AiConfig config) {
    final provider = providerFor(config);
    EmbeddingService? embeddings;

    if (config.providerId == 'ollama') {
      // Ollama embeddings via /api/embeddings on the user's host.
      embeddings = EmbeddingService(
        modelId: 'nomic-embed-text',
        embedFn: (text) => _ollamaEmbed(config, text),
      );
    } else if (config.apiKey?.isNotEmpty == true) {
      embeddings = EmbeddingService(
        modelId: 'gemini-embedding-001',
        embedFn: (text) => provider.embed(text, config),
      );
    }

    return RagService(
      datasource: _datasource,
      provider: provider,
      embeddings: embeddings,
    );
  }

  Future<List<double>?> _ollamaEmbed(AiConfig config, String text) async {
    // Implemented via OpenAiCompatibleProvider's HTTP stack for consistency.
    return OllamaProvider().embed(text, config);
  }
}
