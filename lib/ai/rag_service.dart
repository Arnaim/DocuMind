import '../core/constants/app_constants.dart';
import '../core/utils/text_utils.dart';
import '../data/datasources/app_database.dart';
import '../data/datasources/library_datasource.dart';
import '../data/models/models.dart';
import 'ai_provider.dart';
import 'embedding_service.dart';
import 'prompts.dart';

/// The scope of an AI request: one document, several documents, or a whole
/// collection. Resolved to document ids before retrieval.
class RagScope {
  final List<String> documentIds;
  final bool entireLibrary;

  const RagScope.documents(this.documentIds) : entireLibrary = false;
  const RagScope.library() : documentIds = const [], entireLibrary = true;
}

/// One retrieved passage with its retrieval score.
class RetrievedChunk {
  final Chunk chunk;
  final Document document;
  final double score;
  final double? vectorScore;

  const RetrievedChunk({
    required this.chunk,
    required this.document,
    required this.score,
    this.vectorScore,
  });

  String get displayTitle => document.title;
}

/// The full result of answering a question: answer text with [Sn] markers
/// already resolved to real citations.
class RagAnswer {
  final String answer;
  final List<Citation> citations;
  final List<RetrievedChunk> usedChunks;

  const RagAnswer({
    required this.answer,
    required this.citations,
    required this.usedChunks,
  });
}

/// Hybrid RAG pipeline:
///   question → (lexical FTS5 + optional vector search) → re-rank → context
///   → provider → answer → citation resolution.
///
/// Anti-hallucination is enforced in two places:
///  1. The system prompt forbids invented citations (see prompts.dart).
///  2. Post-processing drops any [Sn] marker that doesn't map to a real
///     provided source and only keeps citations for chunks actually used.
class RagService {
  final LibraryDatasource _datasource;
  final AiProvider _provider;
  final EmbeddingService? _embeddings;

  RagService({
    required LibraryDatasource datasource,
    required AiProvider provider,
    EmbeddingService? embeddings,
  })  : _datasource = datasource,
        _provider = provider,
        _embeddings = embeddings;

  /// Answers [question] grounded in the documents selected by [scope].
  Future<RagAnswer> answer({
    required String question,
    required RagScope scope,
    required AiConfig config,
    AiTask task = AiTask.questionAnswering,
    String? instructionOverride,
    List<String> conversationContext = const [],
  }) async {
    final retrieved = await retrieve(question: question, scope: scope);

    if (retrieved.isEmpty) {
      return RagAnswer(
        answer: _noContextAnswer(scope),
        citations: const [],
        usedChunks: const [],
      );
    }

    final sources = retrieved
        .map((r) => ContextSource(
              documentTitle: r.document.title,
              page: r.chunk.pageNumber,
              section: r.chunk.section,
              text: r.chunk.text,
            ))
        .toList();

    final system = PromptBuilder.systemFor(task);
    final context = PromptBuilder.contextBlock(sources);
    final userBuffer = StringBuffer();
    for (final line in conversationContext) {
      userBuffer.writeln(line);
    }
    userBuffer.writeln('USER QUESTION: $question');
    if (instructionOverride != null) {
      userBuffer.writeln();
      userBuffer.writeln(instructionOverride);
    }
    userBuffer.writeln();
    userBuffer.writeln(context);

    final response = await _provider.complete(
      AiRequest(
        systemPrompt: system,
        userPrompt: userBuffer.toString(),
      ),
      config,
    );

    final resolved = _resolveCitations(response.text, retrieved);
    return RagAnswer(
      answer: resolved.cleanedText,
      citations: resolved.citations,
      usedChunks: retrieved,
    );
  }

  /// Retrieves the top relevant chunks for a question within [scope].
  Future<List<RetrievedChunk>> retrieve({
    required String question,
    required RagScope scope,
  }) async {
    final docs = await _resolveDocuments(scope);
    if (docs.isEmpty) return const [];
    final docIds = docs.map((d) => d.id).toSet();
    _docCache
      ..clear()
      ..addEntries(docs.map((d) => MapEntry(d.id, d)));

    // 1. Lexical candidates via FTS5.
    final lexical = await _lexicalSearch(question, docIds);

    // 2. Semantic candidates via local cosine over stored vectors.
    var semantic = <RetrievedChunk>[];
    if (_embeddings != null) {
      final queryVec = await _embeddings.embedQuery(question);
      if (queryVec != null && queryVec.isNotEmpty) {
        semantic = await _vectorSearch(queryVec, docIds);
      }
    }

    // 3. Merge: union by chunk id, score = max(lexical, semantic) with a
    //    bonus when both retrieval paths agree.
    final byId = <String, RetrievedChunk>{};
    for (final r in semantic) {
      byId[r.chunk.id] = r;
    }
    for (final r in lexical) {
      final existing = byId[r.chunk.id];
      if (existing == null) {
        byId[r.chunk.id] = r;
      } else {
        byId[r.chunk.id] = RetrievedChunk(
          chunk: existing.chunk,
          document: existing.document,
          score: existing.score + 0.25, // agreement bonus
          vectorScore: existing.vectorScore,
        );
      }
    }

    final merged = byId.values.toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    // 4. Trim to the context budget.
    final result = <RetrievedChunk>[];
    var used = 0;
    for (final r in merged) {
      if (result.length >= AppConstants.ragContextChunks) break;
      if (used + r.chunk.text.length > AppConstants.maxContextChars) continue;
      result.add(r);
      used += r.chunk.text.length;
    }
    return result;
  }

  Future<List<Document>> _resolveDocuments(RagScope scope) async {
    if (scope.entireLibrary) {
      return _datasource.listDocuments();
    }
    final docs = <Document>[];
    for (final id in scope.documentIds) {
      final d = await _datasource.getDocument(id);
      if (d != null) docs.add(d);
    }
    return docs;
  }

  Future<List<RetrievedChunk>> _lexicalSearch(
      String question, Set<String> docIds) async {
    final db = await AppDatabase.open();
    final ftsQuery = sanitizeFtsQuery(question);
    if (ftsQuery.isEmpty) return const [];

    final rows = await db.rawQuery('''
      SELECT c.id, c.document_id, rank
      FROM chunks_fts f
      JOIN chunks c ON c.rowid = f.rowid
      WHERE chunks_fts MATCH ?
      ORDER BY rank
      LIMIT ?
    ''', [ftsQuery, AppConstants.ftsCandidateCount]);

    final scores = <String, double>{};
    for (final row in rows) {
      final docId = row['document_id'] as String;
      if (!docIds.contains(docId)) continue;
      // rank is negative BM25 (more negative = better); normalize crudely.
      final rank = (row['rank'] as num?)?.toDouble() ?? -1;
      scores[row['id'] as String] = 1.0 / (1.0 + rank.abs() * 0.05);
    }
    if (scores.isEmpty) return const [];

    final chunks = await _chunksById(scores.keys.toList());
    final out = <RetrievedChunk>[];
    for (final c in chunks) {
      if (!docIds.contains(c.documentId)) continue;
      final doc = _docCache[c.documentId];
      if (doc == null) continue;
      out.add(RetrievedChunk(
        chunk: c,
        document: doc,
        score: scores[c.id] ?? 0.5,
      ));
    }
    return out;
  }

  Future<List<RetrievedChunk>> _vectorSearch(
      List<double> queryVec, Set<String> docIds) async {
    final rows = await _datasource.loadEmbeddings(docIds.toList());
    final best = <({String chunkId, String docId, double score})>[];
    for (final row in rows) {
      final score = EmbeddingService.cosine(queryVec, row.vector);
      if (score >= AppConstants.minSemanticScore) {
        best.add((chunkId: row.chunkId, docId: row.documentId, score: score));
      }
    }
    best.sort((a, b) => b.score.compareTo(a.score));
    final top = best.take(AppConstants.ragContextChunks * 2).toList();
    if (top.isEmpty) return const [];

    final chunks = await _chunksById(top.map((t) => t.chunkId).toList());
    final out = <RetrievedChunk>[];
    for (final t in top) {
      final c = chunks.where((c) => c.id == t.chunkId).firstOrNull;
      if (c == null) continue;
      final doc = _docCache[c.documentId];
      if (doc == null) continue;
      out.add(RetrievedChunk(
        chunk: c,
        document: doc,
        score: t.score,
        vectorScore: t.score,
      ));
    }
    return out;
  }

  Future<List<Chunk>> _chunksById(Iterable<String> ids) async {
    final db = await AppDatabase.open();
    final idList = ids.toList();
    if (idList.isEmpty) return const [];
    final placeholders = List.filled(idList.length, '?').join(',');
    final rows = await db.query('chunks',
        where: 'id IN ($placeholders)', whereArgs: idList);
    return rows.map(Chunk.fromRow).toList();
  }

  /// Document cache filled by [retrieve]; both search paths read it so
  /// titles come from one place.
  final Map<String, Document> _docCache = {};

  /// Resolves [Sn] markers in the model output to citations; markers that do
  /// not correspond to a provided source are stripped (never fabricate).
  ({String cleanedText, List<Citation> citations}) _resolveCitations(
      String text, List<RetrievedChunk> sources) {
    final markerRe = RegExp(r'\[S(\d+)\]');
    final usedIndexes = <int>{};
    final cleaned = text.replaceAllMapped(markerRe, (m) {
      final n = int.parse(m.group(1)!);
      if (n >= 1 && n <= sources.length) {
        usedIndexes.add(n - 1);
        return ''; // markers are removed from the visible text
      }
      return ''; // unknown marker: dropped, not fabricated
    });

    final citations = <Citation>[];
    for (final i in usedIndexes.toList()..sort()) {
      final r = sources[i];
      citations.add(Citation(
        chunkId: r.chunk.id,
        documentId: r.document.id,
        documentTitle: r.document.title,
        page: r.chunk.pageNumber,
        section: r.chunk.section,
        snippet: buildSnippet(r.chunk.text, '', padding: 140),
      ));
    }
    return (cleanedText: cleaned.trim(), citations: citations);
  }

  String _noContextAnswer(RagScope scope) =>
      'I could not find relevant passages in the selected documents to answer this. '
      'Try a different question, widen the search scope, or make sure the documents '
      'finished indexing.';
}
