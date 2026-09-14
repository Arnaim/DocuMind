import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../ai/ai_service_factory.dart';
import '../core/errors/app_exceptions.dart';
import '../data/datasources/library_datasource.dart';
import '../data/models/models.dart';
import '../data/repositories/library_repository.dart';
import '../data/datasources/library_datasource.dart' show DocumentSort;
import '../state/settings_provider.dart';

/// Central document-library state. Owns the import pipeline (file → parse →
/// chunk → index → embeddings) and exposes queryable lists for the UI.
class LibraryProvider extends ChangeNotifier {
  final LibraryRepository _repository;
  final LibraryDatasource _datasource;
  final SettingsProvider _settings;

  List<Document> _documents = [];
  List<Collection> _collections = [];
  Map<String, int> _collectionSizes = {};
  bool _loading = false;
  String? _lastError;

  // Per-document pipeline progress (import time).
  final Map<String, PipelineProgress> _progress = {};

  LibraryProvider({
    required LibraryRepository repository,
    required LibraryDatasource datasource,
    required SettingsProvider settings,
  })  : _repository = repository,
        _datasource = datasource,
        _settings = settings {
    // Re-index embeddings in the background when an API key first appears.
    _settings.addListener(_onSettingsChanged);
  }

  List<Document> get documents => _documents;
  List<Collection> get collections => _collections;
  Map<String, int> get collectionSizes => _collectionSizes;
  bool get loading => _loading;
  String? get lastError => _lastError;
  PipelineProgress? progressFor(String id) => _progress[id];

  /// Library query with live filters (search-as-you-type, favorites, sort).
  Future<void> refreshWithFilter({
    String? query,
    bool? favoritesOnly,
    DocumentSort? sort,
  }) async {
    try {
      _documents = await _repository.listDocuments(
        query: query,
        favoritesOnly: favoritesOnly,
        sort: sort ?? DocumentSort.recent,
      );
      _lastError = null;
    } catch (e) {
      _lastError = 'Could not load your library: ${e.toString()}';
    }
    notifyListeners();
  }

  /// Documents currently inside a collection.
  Future<List<Document>> listDocumentsInCollection(String collectionId) =>
      _repository.listDocuments(collectionId: collectionId);

  /// Fetches one document by id (null when missing/deleted).
  Future<Document?> getDocument(String id) => _repository.getDocument(id);

  // ---- Loading -----------------------------------------------------------------

  Future<void> refresh() async {
    _loading = true;
    notifyListeners();
    try {
      _documents = await _repository.listDocuments();
      _collections = await _repository.listCollections();
      _collectionSizes = await _repository.collectionSizes();
      _lastError = null;
    } catch (e) {
      _lastError = 'Could not load your library: ${e.toString()}';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ---- Import pipeline -----------------------------------------------------------

  /// Imports files picked by the user and processes them in the background.
  /// Returns the number of documents successfully queued.
  Future<int> importPickedFiles(List<String> paths) async {
    var queued = 0;
    for (final path in paths) {
      try {
        final doc = await _repository.importFile(path);
        _progress[doc.id] = PipelineProgress(stage: 'Queued', progress: 0);
        queued++;
        notifyListeners();
        // Fire-and-forget: the pipeline updates progress via callbacks.
        unawaited(_processInBackground(doc));
      } on DocuMindException catch (e) {
        _lastError = e.message + (e.hint != null ? '\n${e.hint}' : '');
        notifyListeners();
      }
    }
    await refresh();
    return queued;
  }

  Future<void> _processInBackground(Document doc) async {
    try {
      await _repository.processDocument(
        doc,
        onProgress: (p, stage) {
          _progress[doc.id] = PipelineProgress(stage: stage, progress: p);
          notifyListeners();
        },
      );
      await _tryEmbedDocument(doc.id);
    } catch (e) {
      _progress[doc.id] = PipelineProgress(
        stage: 'Failed',
        progress: 1,
        error: e is DocuMindException ? e.message : 'Processing failed.',
      );
    } finally {
      Future.delayed(const Duration(seconds: 4), () {
        _progress.remove(doc.id);
        notifyListeners();
      });
      await refresh();
    }
  }

  /// Best-effort embedding of a document's chunks (semantic search). Fails
  /// silently to lexical-only when no API key is configured or offline.
  Future<void> _tryEmbedDocument(String documentId) async {
    try {
      final config = _settings.aiConfig;
      if (config.apiKey?.isNotEmpty != true && config.providerId != 'ollama') {
        return;
      }
      final factory = AiServiceFactory(_datasource);
      final provider = factory.providerFor(config);
      final chunks = await _datasource.getChunksForDocument(documentId);
      var count = 0;
      for (final chunk in chunks) {
        final vector = await provider.embed(chunk.text, config);
        if (vector == null) break;
        await _datasource.insertEmbedding(
          chunkId: chunk.id,
          documentId: documentId,
          model: config.providerId,
          vector: vector,
        );
        count++;
      }
      if (count > 0) {
        final doc = await _datasource.getDocument(documentId);
        if (doc != null) {
          await _datasource.updateDocument(doc.copyWith(hasEmbeddings: true));
        }
      }
    } catch (_) {
      // Embeddings are optional; lexical FTS remains available.
    }
  }

  /// Re-embeds every document (Settings action, after changing provider/key).
  Future<void> reindexEmbeddings() async {
    for (final doc in _documents) {
      await _tryEmbedDocument(doc.id);
    }
    await refresh();
  }

  // ---- Document management ---------------------------------------------------------

  Future<void> setFavorite(String id, bool favorite) async {
    await _repository.setFavorite(id, favorite);
    await refresh();
  }

  Future<void> renameDocument(String id, String title) async {
    await _repository.renameDocument(id, title);
    await refresh();
  }

  Future<void> markOpened(String id) async {
    await _repository.markOpened(id);
  }

  Future<void> deleteDocument(String id) async {
    await _repository.deleteDocument(id);
    await refresh();
  }

  Future<void> reprocess(String id) async {
    final doc = await _repository.getDocument(id);
    if (doc == null) return;
    _progress[doc.id] = PipelineProgress(stage: 'Queued', progress: 0);
    notifyListeners();
    await _processInBackground(doc);
  }

  // ---- Collections -------------------------------------------------------------------

  Future<void> createCollection(String name) async {
    await _repository.createCollection(name);
    await refresh();
  }

  Future<void> deleteCollection(String id) async {
    await _repository.deleteCollection(id);
    await refresh();
  }

  Future<void> renameCollection(String id, String name) async {
    await _repository.renameCollection(id, name);
    await refresh();
  }

  Future<void> moveDocument(String documentId, String collectionId, bool add) async {
    await _repository.moveDocumentToCollection(documentId, collectionId, add);
    await refresh();
  }

  Future<List<String>> collectionIdsForDocument(String documentId) =>
      _repository.collectionIdsForDocument(documentId);

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    // When an API key is added, embedding becomes possible for future docs;
    // existing docs can be re-indexed from Settings.
  }
}

/// Live processing state for one document.
class PipelineProgress {
  final String stage;
  final double progress;
  final String? error;

  const PipelineProgress({
    required this.stage,
    required this.progress,
    this.error,
  });
}
