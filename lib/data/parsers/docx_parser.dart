import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../../core/constants/doc_formats.dart';
import '../../core/errors/app_exceptions.dart';
import 'parser_registry.dart';

/// DOCX parser. A .docx is a ZIP archive containing WordprocessingML; we pull
/// `word/document.xml` and convert block-level elements (paragraphs, tables)
/// into text. Tables become pipe-delimited rows so table content stays
/// searchable and quotable in citations.
class DocxParser implements DocumentParser {
  const DocxParser();

  @override
  DocFormat get format => DocFormat.docx;

  @override
  Future<ExtractedDocument> parse(String path) async {
    Archive archive;
    try {
      final bytes = await File(path).readAsBytes();
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (e) {
      throw ParseException(
        'This DOCX file could not be opened.',
        hint: 'It may be corrupted, or actually an older .doc file — .doc is not supported.',
        cause: e,
      );
    }

    final entry =
        archive.files.where((f) => f.name == 'word/document.xml').firstOrNull;
    if (entry == null) {
      throw ParseException(
        'This file does not look like a valid Word document.',
        hint: 'The word/document.xml part is missing.',
      );
    }

    try {
      final xmlText = utf8.decode(entry.content as List<int>);
      final document = XmlDocument.parse(xmlText);
      final body = document.rootElement.findAllElements('w:body').firstOrNull;

      final buffer = StringBuffer();
      var extracted = 0;
      if (body != null) {
        for (final node in body.children.whereType<XmlElement>()) {
          final local = node.name.local;
          if (local == 'p') {
            final text = _paragraphText(node);
            if (text.trim().isNotEmpty) {
              buffer.writeln(text);
              buffer.writeln();
              extracted += text.length;
            }
          } else if (local == 'tbl') {
            final table = _tableText(node);
            if (table.isNotEmpty) {
              buffer.writeln(table);
              buffer.writeln();
              extracted += table.length;
            }
          }
        }
      }

      if (extracted < 10) throw EmptyDocumentException();

      return ExtractedDocument(
        plainText: buffer.toString(),
        pageCount: (extracted / 3000).ceil().clamp(1, 10000),
      );
    } on DocuMindException {
      rethrow;
    } catch (e) {
      throw ParseException(
        'This Word document could not be parsed.',
        hint: 'The XML content may use an unsupported variant. Re-saving from Word usually fixes it.',
        cause: e,
      );
    }
  }

  /// Joins all w:t runs, converting w:tab to spaces and w:br to newlines.
  String _paragraphText(XmlElement paragraph) {
    final buffer = StringBuffer();
    for (final node in paragraph.descendants) {
      if (node is! XmlElement) continue;
      switch (node.name.local) {
        case 't':
          buffer.write(node.innerText);
          break;
        case 'tab':
          buffer.write('  ');
          break;
        case 'br':
          buffer.writeln();
          break;
      }
    }
    return buffer.toString();
  }

  String _tableText(XmlElement table) {
    final rows = <String>[];
    for (final tr in table.findAllElements('w:tr')) {
      final cells = tr.findAllElements('w:tc').map((tc) {
        final parts = <String>[];
        for (final p in tc.findAllElements('w:p')) {
          final t = _paragraphText(p).trim();
          if (t.isNotEmpty) parts.add(t);
        }
        return parts.join(' ');
      }).toList();
      if (cells.any((c) => c.isNotEmpty)) {
        rows.add('| ${cells.join(' | ')} |');
      }
    }
    return rows.join('\n');
  }
}

extension FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
