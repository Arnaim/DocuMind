import 'dart:convert';
import 'dart:io';

import '../../core/constants/doc_formats.dart';
import '../../core/errors/app_exceptions.dart';
import 'parser_registry.dart';

/// Plain-text parser. Detects page breaks (form feed) when present.
class TxtParser implements DocumentParser {
  const TxtParser();

  @override
  DocFormat get format => DocFormat.txt;

  @override
  Future<ExtractedDocument> parse(String path) async {
    final raw = await _read(path);
    final text = raw.replaceAll('\r\n', '\n').trim();
    if (text.isEmpty) throw EmptyDocumentException();

    final pages = text.split('\f');
    if (pages.length > 1) {
      final buffer = StringBuffer();
      for (var i = 0; i < pages.length; i++) {
        buffer.writeln('[page ${i + 1}]');
        buffer.writeln(pages[i].trim());
        buffer.writeln();
      }
      return ExtractedDocument(plainText: buffer.toString(), pageCount: pages.length);
    }
    return ExtractedDocument(plainText: text, pageCount: 1);
  }

  Future<String> _read(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      return utf8.decode(bytes, allowMalformed: true);
    } on FileSystemException {
      throw ParseException('The file could not be read from disk.');
    }
  }
}

/// Markdown parser. Keeps headings as `[heading] Title` lines so the chunker
/// can lift them into chunk section metadata.
class MarkdownParser implements DocumentParser {
  const MarkdownParser();

  @override
  DocFormat get format => DocFormat.markdown;

  @override
  Future<ExtractedDocument> parse(String path) async {
    final raw = await File(path).readAsString();
    final text = raw.replaceAll('\r\n', '\n').trim();
    if (text.isEmpty) throw EmptyDocumentException();

    final buffer = StringBuffer();
    var currentPage = 1;
    // Rough pagination: one page marker every ~3000 characters of content.
    var charsSinceMarker = 0;

    for (final line in text.split('\n')) {
      if (charsSinceMarker > 3000) {
        currentPage++;
        buffer.writeln('[page $currentPage]');
        charsSinceMarker = 0;
      }
      final trimmed = line.trim();
      if (trimmed.startsWith('#')) {
        buffer.writeln();
        buffer.writeln(trimmed);
        buffer.writeln();
        charsSinceMarker += trimmed.length;
      } else {
        buffer.writeln(line);
        charsSinceMarker += line.length;
      }
    }

    return ExtractedDocument(
      plainText: buffer.toString(),
      pageCount: currentPage,
      hasStructure: text.contains(RegExp(r'^#{1,6}\s', multiLine: true)),
    );
  }
}
