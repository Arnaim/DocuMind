import '../constants/app_constants.dart';

/// The result of chunking a document's text.
class TextChunk {
  final int index;
  final String text;
  final int page;
  final String? section;

  const TextChunk({
    required this.index,
    required this.text,
    this.page = 1,
    this.section,
  });
}

/// Splits extracted document text into retrieval-sized chunks.
///
/// Strategy: accumulate whole paragraphs until the target size is reached,
/// keep a small tail from the previous chunk as overlap, and merge a very
/// short final chunk into its predecessor. Page markers of the form
/// `[page 12]` or `[[PAGE 12]]` (emitted by parsers) are detected and become
/// chunk metadata rather than noise in the stored text.
class Chunker {
  static final _pageMarker = RegExp(
    r'\[+\s*page\s*:?\s*(\d+)\s*\]+',
    caseSensitive: false,
  );

  /// Splits [text] into chunks of roughly [AppConstants.chunkSizeChars].
  static List<TextChunk> chunk(String text, {int startPage = 1}) {
    final paragraphs = _splitParagraphs(text);
    final chunks = <TextChunk>[];
    final buffer = StringBuffer();
    var currentPage = startPage;
    var chunkPage = startPage;
    String? chunkSection;

    void flush() {
      if (buffer.length == 0) return;
      final raw = buffer.toString().trim();
      buffer.clear();
      if (raw.isEmpty) return;

      chunks.add(TextChunk(
        index: chunks.length,
        text: raw,
        page: chunkPage,
        section: chunkSection,
      ));
    }

    for (final paragraph in paragraphs) {
      // A standalone page marker flushes the current chunk, updates the page
      // counter and is kept out of the chunk content (it is metadata).
      final marker = _pageMarker.firstMatch(paragraph);
      if (marker != null &&
          paragraph.trim().length < 20 &&
          marker.group(0)!.trim().length >= paragraph.trim().length - 2) {
        flush();
        final page = int.tryParse(marker.group(1)!);
        if (page != null) currentPage = page;
        chunkPage = currentPage;
        chunkSection = null;
        continue;
      }

      // A single paragraph bigger than the target becomes its own chunks.
      if (paragraph.length > AppConstants.chunkSizeChars * 1.5) {
        flush();
        chunks.addAll(_splitLargeParagraph(paragraph, currentPage));
        chunkPage = currentPage;
        chunkSection = null;
        continue;
      }

      if (buffer.length + paragraph.length > AppConstants.chunkSizeChars) {
        flush();
      }
      if (buffer.isEmpty) {
        chunkPage = currentPage;
        chunkSection = _detectHeading(paragraph);
      } else {
        chunkSection ??= _detectHeading(paragraph);
      }
      buffer.writeln(paragraph);
    }
    flush();

    return chunks;
  }

  /// Splits on blank lines; a document without blank lines falls back to
  /// sentence-boundary splitting so the chunker never returns one giant block.
  static List<String> _splitParagraphs(String text) {
    var normalized = text.replaceAll('\r\n', '\n');
    final parts = normalized.split(RegExp(r'\n\s*\n'));
    if (parts.length <= 1) {
      // No blank lines — split on sentence ends to keep chunk sizes sane.
      final sentences = normalized
          .split(RegExp(r'(?<=[.!?])\s+'))
          .where((s) => s.trim().isNotEmpty)
          .toList();
      return sentences;
    }
    return parts.map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
  }

  static List<TextChunk> _splitLargeParagraph(String paragraph, int page) {
    final out = <TextChunk>[];
    var cursor = 0;
    while (cursor < paragraph.length) {
      var end = (cursor + AppConstants.chunkSizeChars).clamp(0, paragraph.length);
      if (end < paragraph.length) {
        final breakPoint = paragraph.lastIndexOf(' ', end);
        if (breakPoint > cursor + AppConstants.chunkSizeChars ~/ 2) {
          end = breakPoint;
        }
      }
      out.add(TextChunk(
        index: 0,
        text: paragraph.substring(cursor, end).trim(),
        page: page,
      ));
      cursor = end - AppConstants.chunkOverlapChars;
      if (cursor < 0) cursor = end;
    }
    for (var i = 0; i < out.length; i++) {
      out[i] = TextChunk(
        index: i,
        text: out[i].text,
        page: out[i].page,
        section: out[i].section,
      );
    }
    return out.where((c) => c.text.length >= AppConstants.minChunkChars).toList();
  }

  /// Heuristic: Markdown headings, ALL-CAPS lines and "1. Title" patterns are
  /// treated as section labels for the chunk that follows them.
  static String? _detectHeading(String paragraph) {
    final t = paragraph.trim();
    if (t.startsWith('#')) {
      return t.replaceAll(RegExp(r'^#+\s*'), '').takeFirst(80);
    }
    if (t.length < 80 && RegExp(r'^[A-Z0-9][A-Z0-9 \-:,\.]+$').hasMatch(t)) {
      return t;
    }
    if (t.length < 80 && RegExp(r'^\d+[\.\)]\s+\S').hasMatch(t)) {
      return t;
    }
    return null;
  }
}

extension on String {
  String takeFirst(int n) =>
      length <= n ? this : '${substring(0, n)}…';
}

/// Adds overlap to a list of chunks by prepending the tail of the previous
/// chunk's text. Called by the pipeline after initial chunking.
List<TextChunk> applyOverlap(List<TextChunk> chunks) {
  if (chunks.length < 2) return chunks;
  final result = <TextChunk>[];
  for (var i = 0; i < chunks.length; i++) {
    if (i == 0) {
      result.add(chunks[i]);
      continue;
    }
    final prev = chunks[i - 1].text;
    final overlap = prev.length > AppConstants.chunkOverlapChars
        ? prev.substring(prev.length - AppConstants.chunkOverlapChars)
        : prev;
    final text = '$overlap ${chunks[i].text}';
    result.add(TextChunk(
      index: i,
      text: text,
      page: chunks[i].page,
      section: chunks[i].section,
    ));
  }
  return result;
}
