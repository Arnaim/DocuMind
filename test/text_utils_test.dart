import 'package:flutter_test/flutter_test.dart';
import 'package:documind/core/utils/text_utils.dart';

void main() {
  group('buildSnippet', () {
    test('centers the snippet on the query match', () {
      final text =
          'Lorem ipsum dolor sit amet. The attention mechanism allows models to '
          'focus. Consectetur adipiscing elit sed do eiusmod tempor incididunt.';
      final snippet = buildSnippet(text, 'attention mechanism', padding: 30);

      expect(snippet, contains('attention mechanism'));
      // Padding keeps it short.
      expect(snippet.length, lessThan(120));
    });

    test('falls back to text start when the query is missing', () {
      final snippet = buildSnippet('Just some text without the phrase.', 'zzz');
      expect(snippet, startsWith('Just some text'));
    });

    test('collapses whitespace', () {
      final snippet = buildSnippet('word\n\n   spaced\tout  text here', 'spaced');
      expect(snippet, isNot(contains('\n')));
      expect(snippet, isNot(contains('\t')));
    });

    test('returns empty string for empty text', () {
      expect(buildSnippet('', 'query'), '');
    });
  });

  group('sanitizeFtsQuery', () {
    test('produces OR-joined prefix queries and strips operators', () {
      final q = sanitizeFtsQuery('attention "mechan" AND (neural)');
      expect(q, 'attention* OR mechan* OR AND* OR neural*');
    });

    test('caps the number of terms', () {
      final q = sanitizeFtsQuery('a b c d e f g h i j k l m n o');
      expect(q.split(' OR ').length, lessThanOrEqualTo(12));
    });

    test('returns empty for punctuation-only input', () {
      expect(sanitizeFtsQuery('!!! @@@ ###'), '');
    });
  });

  group('formatBytes', () {
    test('formats units', () {
      expect(formatBytes(512), '512 B');
      expect(formatBytes(2048), '2 KB');
      expect(formatBytes(5 * 1024 * 1024), '5.0 MB');
    });
  });

  group('countOccurrences', () {
    test('counts case-insensitively', () {
      expect(countOccurrences('Attention attention ATTENTION', 'attention'), 3);
    });
  });
}
