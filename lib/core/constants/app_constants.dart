/// Behaviour toggles and tuning values shared across layers.
class AppConstants {
  AppConstants._();

  // ---- Database ------------------------------------------------------------
  static const String dbName = 'documind.db';
  static const int dbVersion = 1;

  // ---- Chunking ------------------------------------------------------------
  /// Target size of a chunk in characters (roughly 180–250 words).
  static const int chunkSizeChars = 1300;

  /// Overlap between consecutive chunks so sentences spanning boundaries stay
  /// retrievable from at least one side.
  static const int chunkOverlapChars = 150;

  /// Chunks shorter than this are merged forward rather than emitted alone.
  static const int minChunkChars = 60;

  // ---- Retrieval -----------------------------------------------------------
  /// Lexical (FTS5) candidates fetched before re-ranking.
  static const int ftsCandidateCount = 60;

  /// Semantic + lexical shortlist handed to the LLM as grounding context.
  static const int ragContextChunks = 8;

  /// Maximum context characters assembled for a single AI request.
  static const int maxContextChars = 16000;

  /// How many characters around a match a search snippet shows.
  static const int snippetPadding = 80;

  // ---- AI calls ------------------------------------------------------------
  static const Duration aiRequestTimeout = Duration(seconds: 90);
  static const Duration aiConnectTimeout = Duration(seconds: 20);
  static const int aiMaxOutputTokens = 2048;
  static const double aiDefaultTemperature = 0.2;

  /// Minimum cosine similarity for an embedding to be considered a match.
  static const double minSemanticScore = 0.18;

  // ---- Files ---------------------------------------------------------------
  /// Documents larger than this are rejected before parsing begins.
  static const int maxFileSizeBytes = 120 * 1024 * 1024;

  /// Above this character count the importer warns the user that indexing
  /// will take a while and embeddings are skipped for speed.
  static const int largeDocumentCharThreshold = 900000;

  /// Version stamp written into every embedding row.
  static const int embeddingVersion = 1;
}
