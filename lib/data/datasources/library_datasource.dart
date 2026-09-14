import 'package:sqflite/sqflite.dart';

import '../../core/constants/app_constants.dart';
import '../models/models.dart';
import 'app_database.dart';

/// Direct SQLite access for documents, chunks, collections and embeddings.
/// Repositories build on this; widgets never touch it.
class LibraryDatasource {
  Future<Database> get _db => AppDatabase.open();

  // ---- Documents ------------------------------------------------------------

  Future<void> insertDocument(Document doc) async {
    final db = await _db;
    await db.insert('documents', doc.toRow(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Document?> getDocument(String id) async {
    final db = await _db;
    final rows = await db
        .query('documents', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Document.fromRow(rows.first);
  }

  /// Returns documents matching the filters. [status] null = all statuses.
  Future<List<Document>> listDocuments({
    String? query,
    bool? favoritesOnly,
    String? collectionId,
    ProcessingStatus? status,
    DocumentSort sort = DocumentSort.recent,
  }) async {
    final db = await _db;
    final where = <String>[];
    final args = <Object?>[];

    if (query != null && query.trim().isNotEmpty) {
      where.pushRaw('title LIKE ?', args, '%${query.trim()}%');
    }
    if (favoritesOnly == true) {
      where.add('is_favorite = 1');
    }
    if (status != null) {
      where.pushRaw('status = ?', args, status.name);
    }
    if (collectionId != null) {
      where.pushRaw(
        'id IN (SELECT document_id FROM document_collections WHERE collection_id = ?)',
        args,
        collectionId,
      );
    }

    final orderBy = switch (sort) {
      DocumentSort.recent => 'imported_at DESC',
      DocumentSort.lastOpened => 'last_opened_at IS NULL, last_opened_at DESC',
      DocumentSort.title => 'title COLLATE NOCASE ASC',
      DocumentSort.size => 'file_size DESC',
    };

    final rows = await db.query(
      'documents',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: where.isEmpty ? null : args,
      orderBy: orderBy,
    );
    return rows.map(Document.fromRow).toList();
  }

  Future<void> updateDocument(Document doc) async {
    final db = await _db;
    await db.update('documents', doc.toRow(), where: 'id = ?',
        whereArgs: [doc.id]);
  }

  Future<void> updateDocumentStatus(
      String id, ProcessingStatus status, String? errorMessage) async {
    final db = await _db;
    await db.update(
      'documents',
      {'status': status.name, 'error_message': errorMessage},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteDocument(String id) async {
    final db = await _db;
    await db.delete('documents', where: 'id = ?', whereArgs: [id]);
  }

  Future<bool> existsByFingerprint(String fileName, int fileSize) async {
    final db = await _db;
    final rows = await db.query(
      'documents',
      where: 'file_name = ? AND file_size = ?',
      whereArgs: [fileName, fileSize],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  // ---- Chunks ---------------------------------------------------------------

  Future<void> insertChunks(List<Chunk> chunks) async {
    final db = await _db;
    final batch = db.batch();
    for (final c in chunks) {
      batch.insert('chunks', c.toRow(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Chunk>> getChunksForDocument(String documentId) async {
    final db = await _db;
    final rows = await db.query('chunks',
        where: 'document_id = ?',
        whereArgs: [documentId],
        orderBy: 'position ASC');
    return rows.map(Chunk.fromRow).toList();
  }

  Future<int> chunkCountForDocument(String documentId) async {
    final db = await _db;
    final result = await db.rawQuery(
        'SELECT COUNT(*) AS n FROM chunks WHERE document_id = ?',
        [documentId]);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> deleteChunksForDocument(String documentId) async {
    final db = await _db;
    await db.delete('chunks', where: 'document_id = ?', whereArgs: [documentId]);
  }

  // ---- Embeddings -----------------------------------------------------------

  Future<void> insertEmbedding({
    required String chunkId,
    required String documentId,
    required String model,
    required List<double> vector,
  }) async {
    final db = await _db;
    await db.insert(
      'chunk_embeddings',
      {
        'chunk_id': chunkId,
        'document_id': documentId,
        'model': model,
        'version': AppConstants.embeddingVersion,
        'dim': vector.length,
        'vector': vector.join(' '),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> embeddingCountForDocument(String documentId) async {
    final db = await _db;
    final result = await db.rawQuery(
        'SELECT COUNT(*) AS n FROM chunk_embeddings WHERE document_id = ?',
        [documentId]);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> embeddingCount() async {
    final db = await _db;
    final result =
        await db.rawQuery('SELECT COUNT(*) AS n FROM chunk_embeddings');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Loads every embedding for the given document ids (or all when null).
  /// Returns (chunkId, documentId, vector) triples.
  Future<List<EmbeddingRow>> loadEmbeddings(List<String>? documentIds) async {
    final db = await _db;
    final rows = documentIds == null || documentIds.isEmpty
        ? await db.query('chunk_embeddings')
        : await db.query('chunk_embeddings',
            where:
                'document_id IN (${List.filled(documentIds.length, '?').join(',')})',
            whereArgs: documentIds);
    return rows.map(EmbeddingRow.fromRow).toList();
  }

  // ---- Collections ----------------------------------------------------------

  Future<void> insertCollection(Collection collection) async {
    final db = await _db;
    await db.insert('collections', collection.toRow(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Collection>> listCollections() async {
    final db = await _db;
    final rows = await db.query('collections', orderBy: 'name COLLATE NOCASE');
    return rows.map(Collection.fromRow).toList();
  }

  Future<void> deleteCollection(String id) async {
    final db = await _db;
    await db.delete('collections', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> renameCollection(String id, String name) async {
    final db = await _db;
    await db.update('collections', {'name': name},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> addDocumentToCollection(
      String documentId, String collectionId) async {
    final db = await _db;
    await db.insert('document_collections',
        {'document_id': documentId, 'collection_id': collectionId},
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> removeDocumentFromCollection(
      String documentId, String collectionId) async {
    final db = await _db;
    await db.delete('document_collections',
        where: 'document_id = ? AND collection_id = ?',
        whereArgs: [documentId, collectionId]);
  }

  Future<Map<String, int>> collectionSizes() async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT collection_id, COUNT(*) AS n
      FROM document_collections
      GROUP BY collection_id
    ''');
    return {
      for (final r in rows)
        r['collection_id'] as String: (r['n'] as int?) ?? 0,
    };
  }

  Future<List<String>> collectionIdsForDocument(String documentId) async {
    final db = await _db;
    final rows = await db.query('document_collections',
        columns: ['collection_id'],
        where: 'document_id = ?',
        whereArgs: [documentId]);
    return rows.map((r) => r['collection_id'] as String).toList();
  }

  // ---- Stats (Home dashboard) -------------------------------------------------

  Future<int> documentCount() async {
    final db = await _db;
    final r = await db.rawQuery('SELECT COUNT(*) AS n FROM documents');
    return Sqflite.firstIntValue(r) ?? 0;
  }

  Future<List<Document>> recentDocuments(int limit) async {
    final db = await _db;
    final rows = await db.query('documents',
        orderBy: 'last_opened_at IS NULL, last_opened_at DESC, imported_at DESC',
        limit: limit);
    return rows.map(Document.fromRow).toList();
  }

  Future<List<Document>> favoriteDocuments() async {
    final db = await _db;
    final rows = await db
        .query('documents', where: 'is_favorite = 1', orderBy: 'imported_at DESC');
    return rows.map(Document.fromRow).toList();
  }
}

/// Sort options for the library list.
enum DocumentSort { recent, lastOpened, title, size }

extension on List<String> {
  void pushRaw(String clause, List<Object?> args, Object? arg) {
    add(clause);
    args.add(arg);
  }
}

class EmbeddingRow {
  final String chunkId;
  final String documentId;
  final List<double> vector;

  const EmbeddingRow({
    required this.chunkId,
    required this.documentId,
    required this.vector,
  });

  static EmbeddingRow fromRow(Map<String, Object?> row) => EmbeddingRow(
        chunkId: row['chunk_id'] as String,
        documentId: row['document_id'] as String,
        vector: (row['vector'] as String)
            .split(' ')
            .where((s) => s.isNotEmpty)
            .map(double.parse)
            .toList(),
      );
}
