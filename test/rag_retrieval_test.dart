import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:documind/ai/ai_provider.dart';
import 'package:documind/ai/rag_service.dart';
import 'package:documind/core/constants/doc_formats.dart';
import 'package:documind/data/datasources/app_database.dart';
import 'package:documind/data/datasources/library_datasource.dart';
import 'package:documind/data/models/models.dart';

void main() {
  // Use the FFI implementation so tests run on the host machine.
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late LibraryDatasource datasource;

  setUp(() async {
    // Fresh in-memory database per test, wired into the app singleton.
    final db = await AppDatabase.openInMemory();
    AppDatabase.useForTests(db);
    datasource = LibraryDatasource();
  });

  Document doc(String id) => Document(
        id: id,
        title: 'Paper $id',
        fileName: '$id.pdf',
        filePath: '/tmp/$id.pdf',
        format: DocFormat.pdf,
        fileSizeBytes: 1000,
        importedAt: DateTime(2026, 1, 1),
        modifiedAt: DateTime(2026, 1, 1),
        status: ProcessingStatus.ready,
      );

  Chunk chunk(String id, String docId, String text, {int page = 1}) => Chunk(
        id: id,
        documentId: docId,
        text: text,
        pageNumber: page,
        position: 0,
      );

  group('RagService retrieval + citations', () {
    test('finds relevant chunks lexically and builds citations', () async {
      final d = doc('d1');
      await datasource.insertDocument(d);
      await datasource.insertChunks([
        chunk('d1_c0', 'd1',
            'The attention mechanism allows models to focus on relevant parts.',
            page: 4),
        chunk('d1_c1', 'd1', 'Grocery shopping lists are unrelated.', page: 5),
      ]);

      final provider = _StubProvider();
      final rag = RagService(datasource: datasource, provider: provider);

      final answer = await rag.answer(
        question: 'What does the attention mechanism do?',
        scope: const RagScope.library(),
        config: const AiConfig(providerId: 'stub', model: 'stub'),
      );

      expect(answer.citations, isNotEmpty);
      expect(answer.citations.first.documentTitle, 'Paper d1');
      expect(answer.citations.first.page, 4);
      // The answer passed through the stub.
      expect(answer.answer, contains('stub-answer'));
    });

    test('drops fabricated citation markers the model invented', () async {
      final d = doc('d1');
      await datasource.insertDocument(d);
      await datasource.insertChunks([
        chunk('d1_c0', 'd1', 'Attention is all you need.', page: 3),
      ]);

      final provider = _StubProvider(responseText: 'Claim [S7] and [S1].');
      final rag = RagService(datasource: datasource, provider: provider);

      final answer = await rag.answer(
        question: 'attention',
        scope: const RagScope.library(),
        config: const AiConfig(providerId: 'stub', model: 'stub'),
      );

      // [S7] is fabricated (only 1 source provided) → stripped.
      expect(answer.answer.contains('[S7]'), isFalse);
      // Only one real citation survives.
      expect(answer.citations.length, 1);
      expect(answer.citations.first.chunkId, 'd1_c0');
    });

    test('returns the not-found message when nothing matches', () async {
      final d = doc('d1');
      await datasource.insertDocument(d);
      await datasource.insertChunks([
        chunk('d1_c0', 'd1', 'Completely different content about gardening.'),
      ]);

      final rag = RagService(
          datasource: datasource, provider: _StubProvider());
      final answer = await rag.answer(
        question: 'quantum computing opinions of the author',
        scope: const RagScope.library(),
        config: const AiConfig(providerId: 'stub', model: 'stub'),
      );

      expect(answer.citations, isEmpty);
      expect(answer.answer, contains('could not find'));
    });

    test('respects document scope', () async {
      await datasource.insertDocument(doc('d1'));
      await datasource.insertDocument(doc('d2'));
      await datasource.insertChunks([
        chunk('d1_c0', 'd1', 'Neural networks text in document one.', page: 1),
        chunk('d2_c0', 'd2', 'Neural networks text in document two.', page: 1),
      ]);

      final rag = RagService(
          datasource: datasource, provider: _StubProvider());
      final answer = await rag.answer(
        question: 'neural networks',
        scope: const RagScope.documents(['d2']),
        config: const AiConfig(providerId: 'stub', model: 'stub'),
      );

      expect(answer.citations, isNotEmpty);
      expect(answer.citations.first.documentId, 'd2');
    });
  });
}

/// Deterministic provider stub echoing a fixed answer.
class _StubProvider implements AiProvider {
  final String responseText;
  _StubProvider({this.responseText = 'stub-answer [S1]'});

  @override
  String get displayName => 'Stub';

  @override
  String get id => 'stub';

  @override
  AiProviderKind get kind => AiProviderKind.cloud;

  @override
  List<String> get availableModels => ['stub'];

  @override
  bool get isConfigured => true;

  @override
  String statusLabel(AiConfig config) => 'Ready';

  @override
  Future<AiResponse> complete(AiRequest request, AiConfig config) async {
    // Verify the grounding prompt made it through.
    expect(request.systemPrompt, contains('GROUNDING RULES'));
    expect(request.userPrompt, contains('CONTEXT'));
    return AiResponse(text: responseText);
  }

  @override
  Future<List<double>?> embed(String text, AiConfig config) async => null;
}
