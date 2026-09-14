import 'dart:io';

import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../core/constants/doc_formats.dart';
import '../../core/errors/app_exceptions.dart';
import 'parser_registry.dart';

/// Extracts text page-by-page using SyncFusion PDF. Each page is prefixed with
/// a `[page N]` marker so the chunker can attach page numbers to chunks —
/// this is what makes page-accurate citations possible.
class PdfParser implements DocumentParser {
  const PdfParser();

  @override
  DocFormat get format => DocFormat.pdf;

  @override
  Future<ExtractedDocument> parse(String path) async {
    final file = File(path);
    if (!file.existsSync()) {
      throw ParseException('The PDF file could not be found on disk.');
    }

    final List<int> bytes;
    try {
      bytes = file.readAsBytesSync();
    } on FileSystemException catch (e) {
      throw ParseException('Could not read the PDF file.', cause: e);
    }

    PdfDocument document;
    try {
      document = PdfDocument(inputBytes: bytes);
    } on ArgumentError catch (e) {
      // SyncFusion signals password problems as ArgumentError("password", …).
      if (e.toString().toLowerCase().contains('password')) {
        throw ProtectedDocumentException('This PDF is password-protected.');
      }
      throw ParseException(
        'This PDF appears to be corrupted or is not a valid PDF file.',
        hint: 'Try re-exporting it from the original application.',
        cause: e,
      );
    } catch (e) {
      throw ParseException(
        'This PDF appears to be corrupted or is not a valid PDF file.',
        hint: 'Try re-exporting it from the original application.',
        cause: e,
      );
    }

    try {
      final buffer = StringBuffer();
      var extractedChars = 0;

      for (var i = 0; i < document.pages.count; i++) {
        final pageText = PdfTextExtractor(document).extractText(startPageIndex: i);
        buffer.writeln('[page ${i + 1}]');
        buffer.writeln(pageText);
        buffer.writeln();
        extractedChars += pageText.trim().length;
      }

      final pageCount = document.pages.count;
      document.dispose();

      if (extractedChars < 20) {
        throw EmptyDocumentException();
      }

      return ExtractedDocument(
        plainText: buffer.toString(),
        pageCount: pageCount,
      );
    } on DocuMindException {
      rethrow;
    } catch (e) {
      throw ParseException(
        'Text extraction from this PDF failed partway through.',
        hint: 'The file may be partially corrupted. Re-saving it often fixes this.',
        cause: e,
      );
    } finally {
      try {
        document.dispose();
      } catch (_) {}
    }
  }
}
