import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../core/utils/text_utils.dart';
import '../data/datasources/app_database.dart';
import '../data/models/models.dart';

/// A single search hit: document + page + snippet + relevance.
class SearchHit {
  final Chunk chunk;
  final Document document;
  final String snippet;
  final double score;

  const SearchHit({
    required this.chunk,
    required this.document,
    required this.snippet,
    required this.score,
  });
}

/// Local full-text search over the chunk index. Runs entirely on-device via
/// SQLite FTS5 — works with zero connectivity.
class SearchProvider extends ChangeNotifier {
  List<SearchHit> _hits = [];
  bool _searching = false;
  String _lastQuery = '';

  List<SearchHit> get hits => _hits;
  bool get searching => _searching;
  String get lastQuery => _lastQuery;

  Future<void> search(String query, {String? collectionId}) async {
    final q = query.trim();
    _lastQuery = q;
    if (q.isEmpty) {
      _hits = [];
      notifyListeners();
      return;
    }

    _searching = true;
    notifyListeners();

    try {
      final db = await AppDatabase.open();
      final ftsQuery = sanitizeFtsQuery(q);
      if (ftsQuery.isEmpty) {
        _hits = [];
        return;
      }

      // FTS5 search joined to chunks + documents; bm25 rank for ordering,
      // snippet() for highlighted excerpts.
      final rows = await db.rawQuery('''
        SELECT c.id AS chunk_id,
               c.document_id,
               c.page_number,
               c.section,
               c.position,
               snippet(chunks_fts, 0, '▸', '◂', '…', 24) AS snip,
               bm25(chunks_fts) AS rank,
               d.title AS doc_title
        FROM chunks_fts f
        JOIN chunks c ON c.rowid = f.rowid
        JOIN documents d ON d.id = c.document_id
        WHERE chunks_fts MATCH ?
        ORDER BY rank
        LIMIT 50
      ''', [ftsQuery]);

      final hitBuffer = <SearchHit>[];
      for (final row in rows) {
        final documentId = row['document_id'] as String;
        final document = await _documentFor(documentId);
        if (document == null) continue;
        if (collectionId != null) {
          final inCollection = await _inCollection(documentId, collectionId, db);
          if (!inCollection) continue;
        }
        final chunk = Chunk(
          id: row['chunk_id'] as String,
          documentId: documentId,
          text: row['snip'] as String? ?? '',
          pageNumber: row['page_number'] as int,
          section: row['section'] as String?,
          position: row['position'] as int,
        );
        final rank = (row['rank'] as num?)?.toDouble() ?? -1;
        hitBuffer.add(SearchHit(
          chunk: chunk,
          document: document,
          snippet: row['snip'] as String? ?? '',
          score: 1.0 / (1.0 + rank.abs() * 0.1),
        ));
      }

      _hits = hitBuffer;
    } catch (e) {
      _hits = [];
    } finally {
      _searching = false;
      notifyListeners();
    }
  }

  final Map<String, Document?> _docCache = {};

  Future<Document?> _documentFor(String id) async {
    if (_docCache.containsKey(id)) return _docCache[id];
    final db = await AppDatabase.open();
    final rows =
        await db.query('documents', where: 'id = ?', whereArgs: [id], limit: 1);
    final doc = rows.isEmpty ? null : Document.fromRow(rows.first);
    _docCache[id] = doc;
    return doc;
  }

  Future<bool> _inCollection(
      String documentId, String collectionId, Database db) async {
    final rows = await db.query('document_collections',
        where: 'document_id = ? AND collection_id = ?',
        whereArgs: [documentId, collectionId],
        limit: 1);
    return rows.isNotEmpty;
  }

  void clear() {
    _hits = [];
    _lastQuery = '';
    notifyListeners();
  }
}
