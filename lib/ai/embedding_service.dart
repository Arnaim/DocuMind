import 'dart:convert';
import 'dart:math' as math;

import '../core/constants/app_constants.dart';

/// Embedding + vector math service. Providers plug in via [EmbedFunction];
/// cosine similarity and serialization live here so retrieval code stays
/// provider-agnostic.
class EmbeddingService {
  /// Returns null when embeddings are unavailable (no key, offline, etc).
  final Future<List<double>?> Function(String text) embedFn;
  final String modelId;

  EmbeddingService({required this.embedFn, required this.modelId});

  bool get isAvailable => true;

  /// Embeds a chunk for indexing. Long chunks are trimmed — embedding models
  /// cap input tokens well below what the parsers can emit.
  Future<List<double>?> embedChunk(String text) =>
      embedFn(_trimForEmbedding(text));

  /// Embeds a user query.
  Future<List<double>?> embedQuery(String query) =>
      embedFn(_trimForEmbedding(query));

  /// Cosine similarity, computed locally — vector search never leaves the
  /// device; only the final prompt does.
  static double cosine(List<double> a, List<double> b) {
    if (a.isEmpty || b.isEmpty || a.length != b.length) return 0;
    var dot = 0.0;
    var na = 0.0;
    var nb = 0.0;
    for (var i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      na += a[i] * a[i];
      nb += b[i] * b[i];
    }
    if (na == 0 || nb == 0) return 0;
    return dot / (math.sqrt(na) * math.sqrt(nb));
  }

  static String _trimForEmbedding(String text) {
    final t = text.trim();
    return t.length > AppConstants.chunkSizeChars * 6
        ? t.substring(0, AppConstants.chunkSizeChars * 6)
        : t;
  }

  static String encodeVector(List<double> v) => v.join(' ');

  static List<double> decodeVector(String s) => s
      .split(' ')
      .where((e) => e.isNotEmpty)
      .map(double.parse)
      .toList();

  /// Compact JSON for debugging/export.
  static String describe(List<double> v) =>
      'dim=${v.length} head=${jsonEncode(v.take(4).toList())}';
}
