import 'package:flutter_test/flutter_test.dart';
import 'package:documind/core/utils/chunker.dart';
import 'package:documind/core/constants/app_constants.dart';

void main() {
  group('Chunker.chunk', () {
    test('returns empty list for empty text', () {
      expect(Chunker.chunk(''), isEmpty);
      expect(Chunker.chunk('   \n  \n '), isEmpty);
    });

    test('short text produces a single chunk', () {
      final chunks = Chunker.chunk('Hello world. This is a short document.');
      expect(chunks.length, 1);
      expect(chunks.first.index, 0);
      expect(chunks.first.text, contains('Hello world'));
    });

    test('long text is split into multiple chunks under the size target', () {
      final paragraph = 'The attention mechanism computes weighted relations. ' * 12;
      final text = List.generate(30, (_) => paragraph).join('\n\n');
      final chunks = Chunker.chunk(text);

      expect(chunks.length, greaterThan(1));
      for (final c in chunks) {
        // Allow some tolerance: single paragraphs may exceed the target.
        expect(c.text.length, lessThan(AppConstants.chunkSizeChars * 2.2));
      }
      // Indices are sequential.
      for (var i = 0; i < chunks.length; i++) {
        expect(chunks[i].index, i);
      }
    });

    test('page markers become chunk page metadata', () {
      final text = 'First page content.\n\n[page 2]\n\nSecond page content.';
      final chunks = Chunker.chunk(text);

      expect(chunks.first.page, 1);
      expect(chunks.last.page, 2);
    });

    test('markdown headings become section labels', () {
      final text = '## Attention Mechanism\n\nSelf-attention allows modeling '
          'dependencies without regard to distance.';
      final chunks = Chunker.chunk(text);

      expect(chunks, isNotEmpty);
      expect(chunks.first.section, isNotNull);
      expect(chunks.first.section, contains('Attention Mechanism'));
    });

    test('sentence fallback splits text without blank lines', () {
      final text =
          'Sentence one is here. Sentence two follows. Sentence three ends it. ' * 40;
      final chunks = Chunker.chunk(text);
      expect(chunks.length, greaterThan(1));
    });
  });

  group('applyOverlap', () {
    test('adds tail of previous chunk as overlap', () {
      final chunks = Chunker.chunk(
        List.generate(20, (i) => 'Paragraph number $i with some filler content.')
            .join('\n\n'),
      );
      if (chunks.length < 2) return; // guard for tiny targets

      final overlapped = applyOverlap(chunks);
      expect(overlapped.length, chunks.length);
      // Second chunk begins with (part of) the tail of the first.
      final tail = chunks.first.text
          .substring(chunks.first.text.length - 20);
      expect(overlapped[1].text, contains(tail.trim().split(' ').last));
    });

    test('keeps single-chunk input unchanged', () {
      final chunks = [const TextChunk(index: 0, text: 'only')];
      expect(applyOverlap(chunks).single.text, 'only');
    });
  });
}
