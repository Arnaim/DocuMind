import 'dart:io';

import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/doc_formats.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/services/storage_paths.dart';
import '../../core/utils/chunker.dart';
import '../datasources/library_datasource.dart';
import '../models/models.dart';
import '../parsers/parser_registry.dart';

/// High-level operations on the document library. Coordinates the file system
/// (originals) with the database (metadata, chunks, embeddings).
class LibraryRepository {
  final LibraryDatasource _datasource;
  final ParserRegistry _parsers;
  final _uuid = const Uuid();

  LibraryRepository(this._datasource, this._parsers);

  // ---- Import -----------------------------------------------------------------

  /// Imports a picked file: stores the original, parses it, chunks the text
  /// and writes chunks + FTS. Embeddings are generated separately so import
  /// stays fast and offline-friendly (see [generateEmbeddings]).
  Future<Document> importFile(String sourcePath) async {
    final file = File(sourcePath);
    if (!file.existsSync()) {
      throw DocuMindException(
        'The selected file no longer exists.',
        hint: 'It may have been moved or deleted after being picked.',
      );
    }

    final size = file.lengthSync();
    if (size > AppConstants.maxFileSizeBytes) {
      throw DocuMindException(
        'This file is too large (${(size / (1024 * 1024)).toStringAsFixed(0)} MB).',
        hint: 'The current limit is ${AppConstants.maxFileSizeBytes ~/ (1024 * 1024)} MB.',
      );
    }

    final fileName = file.uri.pathSegments.last;
    final format = DocFormat.fromExtension(fileName);

    if (format == DocFormat.unknown) {
      throw DocuMindException(
        '"$fileName" is not a supported document type.',
        hint: 'Supported: PDF, TXT, Markdown, DOCX'
            '${formatPlannedHint()}',
      );
    }

    if (await _datasource.existsByFingerprint(fileName, size)) {
      throw DocuMindException(
        'This document is already in your library.',
        hint: '"$fileName" with the same size has been imported before.',
      );
    }

    if (!format.isFullySupported) {
      throw ParseException(
        '${format.label} support is on the roadmap but not enabled yet.',
        hint: 'Currently supported: PDF, TXT, Markdown, DOCX.',
      );
    }

    final id = _uuid.v4();
    final storedPath = await StoragePaths.storeFile(id, file);
    final now = DateTime.now();

    final doc = Document(
      id: id,
      title: _prettyTitle(fileName),
      fileName: fileName,
      filePath: storedPath,
      format: format,
      fileSizeBytes: size,
      importedAt: now,
      modifiedAt: now,
      status: ProcessingStatus.imported,
    );
    await _datasource.insertDocument(doc);
    return doc;
  }

  String formatPlannedHint() => '';

  /// Runs parsing + chunking + indexing for a document. Reports progress via
  /// [onProgress] (0.0–1.0). Designed to run outside the UI isolate.
  Future<void> processDocument(
    Document doc, {
    void Function(double progress, String stage)? onProgress,
  }) async {
    try {
      await _datasource.updateDocumentStatus(
          doc.id, ProcessingStatus.processing, null);
      onProgress?.call(0.05, 'Reading file…');

      final parser = _parsers.parserFor(doc.format);
      final extracted = await parser.parse(doc.filePath);
      onProgress?.call(0.45, 'Extracting text…');

      if (extracted.plainText.trim().isEmpty) {
        await _datasource.updateDocumentStatus(doc.id, ProcessingStatus.failed,
            'No selectable text found — the document may be scanned images.');
        throw EmptyDocumentException();
      }

      final chunked = applyOverlap(
          Chunker.chunk(extracted.plainText, startPage: 1));
      onProgress?.call(0.7, 'Chunking…');

      final chunks = <Chunk>[];
      for (final c in chunked) {
        chunks.add(Chunk(
          id: '${doc.id}_c${c.index}',
          documentId: doc.id,
          text: c.text,
          pageNumber: c.page,
          section: c.section,
          position: c.index,
        ));
      }

      await _datasource.deleteChunksForDocument(doc.id);
      await _datasource.insertChunks(chunks);
      onProgress?.call(0.9, 'Indexing…');

      final text = extracted.plainText;
      final pageCount = extracted.pageCount ?? _estimatePageCount(text);
      await _datasource.updateDocument(doc.copyWith(
        pageCount: pageCount,
        charCount: text.length,
        wordCount: Document.estimateWords(text.length),
        status: ProcessingStatus.ready,
        errorMessage: null,
      ));
      onProgress?.call(1.0, 'Ready');
    } on DocuMindException catch (e) {
      await _datasource.updateDocumentStatus(
          doc.id, ProcessingStatus.failed, e.message);
      rethrow;
    } catch (e) {
      await _datasource.updateDocumentStatus(
          doc.id,
          ProcessingStatus.failed,
          'Extraction failed. The file may be corrupted or in an unsupported variant.');
      rethrow;
    }
  }

  int _estimatePageCount(String text) =>
      (text.length / 3000).ceil().clamp(1, 100000);

  // ---- Queries ----------------------------------------------------------------

  Future<List<Document>> listDocuments({
    String? query,
    bool? favoritesOnly,
    String? collectionId,
    DocumentSort sort = DocumentSort.recent,
  }) =>
      _datasource.listDocuments(
          query: query,
          favoritesOnly: favoritesOnly,
          collectionId: collectionId,
          sort: sort);

  Future<Document?> getDocument(String id) => _datasource.getDocument(id);

  Future<void> setFavorite(String id, bool favorite) async {
    final doc = await _datasource.getDocument(id);
    if (doc != null) {
      await _datasource.updateDocument(doc.copyWith(isFavorite: favorite));
    }
  }

  Future<void> renameDocument(String id, String title) async {
    final doc = await _datasource.getDocument(id);
    if (doc != null) {
      await _datasource.updateDocument(doc.copyWith(title: title));
    }
  }

  Future<void> markOpened(String id) async {
    final doc = await _datasource.getDocument(id);
    if (doc != null) {
      await _datasource
          .updateDocument(doc.copyWith(lastOpenedAt: DateTime.now()));
    }
  }

  Future<void> deleteDocument(String id) async {
    await _datasource.deleteDocument(id); // chunks/embeddings cascade
    await StoragePaths.deleteDocumentFolder(id);
  }

  Future<void> reprocessDocument(String id,
      {void Function(double, String)? onProgress}) async {
    final doc = await _datasource.getDocument(id);
    if (doc == null) return;
    await _datasource.deleteChunksForDocument(id);
    await processDocument(doc, onProgress: onProgress);
  }

  // ---- Collections --------------------------------------------------------------

  Future<List<Collection>> listCollections() => _datasource.listCollections();

  Future<Collection> createCollection(String name) async {
    final collection = Collection(
      id: _uuid.v4(),
      name: name.trim(),
      createdAt: DateTime.now(),
    );
    await _datasource.insertCollection(collection);
    return collection;
  }

  Future<void> deleteCollection(String id) => _datasource.deleteCollection(id);

  Future<void> renameCollection(String id, String name) =>
      _datasource.renameCollection(id, name);

  Future<void> moveDocumentToCollection(
          String documentId, String collectionId, bool add) =>
      add
          ? _datasource.addDocumentToCollection(documentId, collectionId)
          : _datasource.removeDocumentFromCollection(documentId, collectionId);

  Future<Map<String, int>> collectionSizes() =>
      _datasource.collectionSizes();

  Future<List<String>> collectionIdsForDocument(String documentId) =>
      _datasource.collectionIdsForDocument(documentId);

  // ---- Dashboard ----------------------------------------------------------------

  Future<int> documentCount() => _datasource.documentCount();

  Future<List<Document>> recentDocuments(int limit) =>
      _datasource.recentDocuments(limit);

  Future<List<Document>> favoriteDocuments() =>
      _datasource.favoriteDocuments();
}

String _prettyTitle(String fileName) {
  final withoutExt = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
  return withoutExt
      .replaceAll(RegExp(r'[_\-]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
