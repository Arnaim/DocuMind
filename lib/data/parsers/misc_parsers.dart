import 'dart:convert';
import 'dart:io';

import 'package:html_unescape/html_unescape.dart';

import '../../core/constants/doc_formats.dart';
import '../../core/errors/app_exceptions.dart';
import 'parser_registry.dart';

/// CSV parser: emits one `[page N]` block per 40 rows with a header reminder so
/// long tables stay navigable and citable by row.
class CsvParser implements DocumentParser {
  const CsvParser();

  @override
  DocFormat get format => DocFormat.csv;

  @override
  Future<ExtractedDocument> parse(String path) async {
    final raw = await File(path).readAsString();
    if (raw.trim().isEmpty) throw EmptyDocumentException();

    final rows = const CsvToListConverter().convert(raw);
    if (rows.isEmpty) throw EmptyDocumentException();

    final header =
        rows.first.map((c) => c.toString().trim()).where((c) => c.isNotEmpty).toList();
    final buffer = StringBuffer();
    var page = 1;
    var inPage = 0;

    buffer.writeln('[page 1]');
    if (header.isNotEmpty) buffer.writeln('Columns: ${header.join(', ')}');

    for (var i = 1; i < rows.length; i++) {
      final cells = rows[i].map((c) => c.toString().trim()).toList();
      final line = cells
          .asMap()
          .entries
          .where((e) => e.value.isNotEmpty)
          .map((e) => '${header.length > e.key ? header[e.key] : 'Column ${e.key + 1}'}: ${e.value}')
          .join('; ');
      if (line.isEmpty) continue;

      if (inPage >= 40) {
        page++;
        buffer.writeln('[page $page]');
        inPage = 0;
      }
      buffer.writeln('Row ${i + 1}. $line');
      inPage++;
    }

    final text = buffer.toString().trim();
    if (text.length < 10) throw EmptyDocumentException();
    return ExtractedDocument(plainText: text, pageCount: page);
  }
}

/// JSON parser: pretty-prints structure and flattens key paths so nested data
/// becomes searchable text like `user.name: Alice`.
class JsonParser implements DocumentParser {
  const JsonParser();

  @override
  DocFormat get format => DocFormat.json;

  @override
  Future<ExtractedDocument> parse(String path) async {
    String raw;
    try {
      raw = await File(path).readAsString();
    } catch (e) {
      throw ParseException('This JSON file could not be read.', cause: e);
    }

    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (e) {
      throw ParseException(
        'This file is not valid JSON.',
        hint: 'Check the syntax around character ${e.offset}.',
        cause: e,
      );
    }

    final buffer = StringBuffer();
    _flatten(decoded, '', buffer, 0);
    final text = buffer.toString().trim();
    if (text.isEmpty) throw EmptyDocumentException();

    return ExtractedDocument(
      plainText: text,
      pageCount: (text.length / 3000).ceil().clamp(1, 10000),
    );
  }

  void _flatten(Object? node, String path, StringBuffer out, int depth) {
    if (depth > 12) {
      out.writeln('$path: …');
      return;
    }
    if (node is Map) {
      node.forEach((key, value) {
        final p = path.isEmpty ? '$key' : '$path.$key';
        _flatten(value, p, out, depth + 1);
      });
    } else if (node is List) {
      for (var i = 0; i < node.length; i++) {
        _flatten(node[i], '$path[$i]', out, depth + 1);
      }
    } else {
      final value = node?.toString() ?? 'null';
      if (value.length > 500) {
        out.writeln('$path: ${value.substring(0, 500)}…');
      } else {
        out.writeln('$path: $value');
      }
    }
  }
}

/// HTML parser: strips tags and scripts, decodes entities, keeps headings on
/// their own lines so sections survive chunking.
class HtmlParser implements DocumentParser {
  static final _script =
      RegExp(r'<(script|style|noscript)[^>]*>[\s\S]*?</\1>', caseSensitive: false);
  static final _heading = RegExp(r'<h([1-6])[^>]*>([\s\S]*?)</h\1>', caseSensitive: false);
  static final _blockTag = RegExp(r'</?(p|div|br|li|tr|table|section|article|header|footer|h[1-6])[^>]*>',
      caseSensitive: false);

  const HtmlParser();

  @override
  DocFormat get format => DocFormat.html;

  @override
  Future<ExtractedDocument> parse(String path) async {
    final raw = await File(path).readAsString();
    if (raw.trim().isEmpty) throw EmptyDocumentException();

    var text = raw.replaceAll(_script, ' ');
    // Preserve heading boundaries.
    text = text.replaceAllMapped(
        _heading, (m) => '\n\n${'#' * int.parse(m.group(1)!)} ${_strip(m.group(2)!)}\n\n');
    // Block tags become paragraph breaks; everything else is removed.
    text = text.replaceAll(_blockTag, '\n');
    text = text.replaceAll(RegExp(r'<[^>]+>'), ' ');
    text = HtmlUnescape().convert(text);
    text = text.replaceAll(RegExp(r'[ \t]+'), ' ');
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();

    if (text.length < 10) {
      throw EmptyDocumentException(
          message: 'This HTML page contains no readable text content.');
    }
    return ExtractedDocument(
      plainText: text,
      pageCount: (text.length / 3000).ceil().clamp(1, 10000),
    );
  }

  static String _strip(String html) =>
      html.replaceAll(RegExp(r'<[^>]+>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Minimal RFC-4180-ish CSV converter (quotes, escaped quotes, commas, CRLF).
class CsvToListConverter {
  const CsvToListConverter();

  List<List<String>> convert(String input) {
    final rows = <List<String>>[];
    var field = StringBuffer();
    var row = <String>[];
    var inQuotes = false;

    for (var i = 0; i < input.length; i++) {
      final c = input[i];
      if (inQuotes) {
        if (c == '"') {
          if (i + 1 < input.length && input[i + 1] == '"') {
            field.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          field.write(c);
        }
      } else {
        if (c == '"') {
          inQuotes = true;
        } else if (c == ',') {
          row.add(field.toString());
          field = StringBuffer();
        } else if (c == '\n') {
          row.add(field.toString());
          rows.add(row);
          row = <String>[];
          field = StringBuffer();
        } else if (c == '\r') {
          continue;
        } else {
          field.write(c);
        }
      }
    }
    if (field.isNotEmpty || row.isNotEmpty) {
      row.add(field.toString());
      rows.add(row);
    }
    return rows;
  }
}
