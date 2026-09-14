import 'package:flutter_test/flutter_test.dart';
import 'package:documind/core/constants/doc_formats.dart';
import 'package:documind/data/models/models.dart';

void main() {
  group('Document', () {
    final doc = Document(
      id: 'd1',
      title: 'Transformer Paper',
      fileName: 'transformer_paper.pdf',
      filePath: '/tmp/x.pdf',
      format: DocFormat.pdf,
      fileSizeBytes: 1024,
      importedAt: DateTime.utc(2026, 1, 1),
      modifiedAt: DateTime.utc(2026, 1, 1),
    );

    test('row round-trip preserves fields', () {
      final restored = Document.fromRow(doc.toRow());
      expect(restored.id, doc.id);
      expect(restored.title, doc.title);
      expect(restored.format, doc.format);
      expect(restored.status, doc.status);
      expect(restored.isFavorite, doc.isFavorite);
    });

    test('copyWith overrides only given fields', () {
      final copy = doc.copyWith(
        title: 'Renamed',
        status: ProcessingStatus.ready,
        isFavorite: true,
      );
      expect(copy.title, 'Renamed');
      expect(copy.status, ProcessingStatus.ready);
      expect(copy.isFavorite, true);
      expect(copy.fileName, doc.fileName);
      expect(copy.filePath, doc.filePath);
    });

    test('estimateWords approximates from character count', () {
      expect(Document.estimateWords(550), 100);
    });
  });

  group('Citation', () {
    test('encode/decode list round-trips', () {
      const citations = [
        Citation(
          chunkId: 'c1',
          documentId: 'd1',
          documentTitle: 'My Doc — with punctuation',
          page: 4,
          section: 'Methods',
          snippet: 'some snippet text',
        ),
        Citation(
          chunkId: 'c2',
          documentId: 'd1',
          documentTitle: 'Other',
          page: 9,
          snippet: 'another',
        ),
      ];

      final encoded = Citation.encodeList(citations);
      final decoded = Citation.decodeList(encoded);

      expect(decoded.length, 2);
      expect(decoded.first.documentTitle, 'My Doc — with punctuation');
      expect(decoded.first.page, 4);
      expect(decoded.first.section, 'Methods');
      expect(decoded.last.chunkId, 'c2');
    });

    test('decode handles corrupt input gracefully', () {
      expect(Citation.decodeList('not json at all'), isEmpty);
      expect(Citation.decodeList(null), isEmpty);
    });
  });

  group('Message/Conversation', () {
    test('message row round-trip keeps citations', () {
      final message = Message(
        id: 'm1',
        conversationId: 'conv1',
        role: MessageRole.assistant,
        content: 'Answer text',
        citations: [
          const Citation(
            chunkId: 'c',
            documentId: 'd',
            documentTitle: 'T',
            page: 2,
            snippet: 's',
          ),
        ],
        createdAt: DateTime.utc(2026, 2, 2),
      );

      final restored = Message.fromRow(message.toRow());
      expect(restored.role, MessageRole.assistant);
      expect(restored.citations.length, 1);
      expect(restored.citations.first.page, 2);
    });

    test('conversation id lists round-trip', () {
      final conv = Conversation(
        id: 'conv1',
        title: 'Test',
        documentIds: ['a', 'b'],
        collectionIds: ['col1'],
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 2),
      );

      final restored = Conversation.fromRow(conv.toRow());
      expect(restored.documentIds, ['a', 'b']);
      expect(restored.collectionIds, ['col1']);
    });
  });

  group('DocFormat', () {
    test('detects from extension case-insensitively', () {
      expect(DocFormat.fromExtension('.PDF'), DocFormat.pdf);
      expect(DocFormat.fromExtension('md'), DocFormat.markdown);
      expect(DocFormat.fromExtension('docx'), DocFormat.docx);
      expect(DocFormat.fromExtension('xyz'), DocFormat.unknown);
    });
  });
}
