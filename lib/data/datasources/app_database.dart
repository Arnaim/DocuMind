import 'package:sqflite/sqflite.dart';

import '../../core/constants/app_constants.dart';

/// SQLite schema for DocuMind.
///
/// Layout:
///  - `documents` / `collections` / `document_collections` — library metadata
///  - `chunks` — extracted text with page/section metadata (citations)
///  - `chunks_fts` — FTS5 full-text index over chunk text (content table)
///  - `chunk_embeddings` — serialized float vectors for semantic search
///  - `conversations` / `messages` — local chat history
///
/// Documents themselves live on the filesystem; the DB stores metadata and
/// references only.
class AppDatabase {
  static Database? _db;

  /// Test hook: replaces the singleton with the given database.
  static void useForTests(Database db) {
    _db = db;
  }

  static Future<Database> open() async {
    if (_db != null) return _db!;
    final db = await openDatabase(
      AppConstants.dbName,
      version: AppConstants.dbVersion,
      onConfigure: (db) async => await db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _create,
      onUpgrade: _upgrade,
    );
    _db = db;
    return db;
  }

  /// Closes the database (used by tests).
  static Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  /// Exposed for tests: open an in-memory database with the same schema.
  static Future<Database> openInMemory() async {
    final db = await openDatabase(inMemoryDatabasePath, version: 1,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: _create);
    return db;
  }

  static Future<void> _create(Database db, int version) async {
    await db.execute('PRAGMA journal_mode = WAL');

    await db.execute('''
      CREATE TABLE documents (
        id            TEXT PRIMARY KEY,
        title         TEXT NOT NULL,
        file_name     TEXT NOT NULL,
        file_path     TEXT NOT NULL,
        format        TEXT NOT NULL,
        file_size     INTEGER NOT NULL,
        imported_at   TEXT NOT NULL,
        modified_at   TEXT NOT NULL,
        last_opened_at TEXT,
        is_favorite   INTEGER NOT NULL DEFAULT 0,
        page_count    INTEGER NOT NULL DEFAULT 1,
        char_count    INTEGER NOT NULL DEFAULT 0,
        word_count    INTEGER NOT NULL DEFAULT 0,
        status        TEXT NOT NULL DEFAULT 'imported',
        error_message TEXT,
        has_embeddings INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_documents_imported ON documents(imported_at DESC)
    ''');

    await db.execute('''
      CREATE TABLE collections (
        id         TEXT PRIMARY KEY,
        name       TEXT NOT NULL UNIQUE,
        created_at TEXT NOT NULL,
        color      TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE document_collections (
        document_id   TEXT NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
        collection_id TEXT NOT NULL REFERENCES collections(id) ON DELETE CASCADE,
        PRIMARY KEY (document_id, collection_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE chunks (
        id          TEXT PRIMARY KEY,
        document_id TEXT NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
        text        TEXT NOT NULL,
        page_number INTEGER NOT NULL DEFAULT 1,
        section     TEXT,
        position    INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_chunks_document ON chunks(document_id, position)
    ''');

    // FTS5 virtual table kept in sync with chunks via triggers.
    await db.execute('''
      CREATE VIRTUAL TABLE chunks_fts USING fts5(
        text,
        content='chunks',
        content_rowid='rowid',
        tokenize='porter unicode61'
      )
    ''');

    await db.execute('''
      CREATE TRIGGER chunks_ai AFTER INSERT ON chunks BEGIN
        INSERT INTO chunks_fts(rowid, text) VALUES (new.rowid, new.text);
      END
    ''');

    await db.execute('''
      CREATE TRIGGER chunks_ad AFTER DELETE ON chunks BEGIN
        INSERT INTO chunks_fts(chunks_fts, rowid, text)
        VALUES ('delete', old.rowid, old.text);
      END
    ''');

    await db.execute('''
      CREATE TRIGGER chunks_au AFTER UPDATE ON chunks BEGIN
        INSERT INTO chunks_fts(chunks_fts, rowid, text)
        VALUES ('delete', old.rowid, old.text);
        INSERT INTO chunks_fts(rowid, text) VALUES (new.rowid, new.text);
      END
    ''');

    // Embeddings are stored as space-separated floats; cosine similarity is
    // computed in Dart over the candidates pre-filtered by lexical search or
    // document scope. For a personal library this is fast enough and avoids a
    // native vector extension dependency.
    await db.execute('''
      CREATE TABLE chunk_embeddings (
        chunk_id    TEXT PRIMARY KEY REFERENCES chunks(id) ON DELETE CASCADE,
        document_id TEXT NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
        model       TEXT NOT NULL,
        version     INTEGER NOT NULL,
        dim         INTEGER NOT NULL,
        vector      TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE conversations (
        id                  TEXT PRIMARY KEY,
        title               TEXT NOT NULL,
        document_ids_json   TEXT NOT NULL DEFAULT '',
        collection_ids_json TEXT NOT NULL DEFAULT '',
        created_at          TEXT NOT NULL,
        updated_at          TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE messages (
        id              TEXT PRIMARY KEY,
        conversation_id TEXT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
        role            TEXT NOT NULL,
        content         TEXT NOT NULL,
        citations_json  TEXT,
        created_at      TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_messages_conversation ON messages(conversation_id, created_at)
    ''');
  }

  static Future<void> _upgrade(
      Database db, int oldVersion, int newVersion) async {
    // Future migrations go here.
  }
}
