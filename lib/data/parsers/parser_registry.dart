import '../../core/constants/doc_formats.dart';
import '../../core/errors/app_exceptions.dart';
import 'docx_parser.dart';
import 'misc_parsers.dart';
import 'pdf_parser.dart';
import 'text_parsers.dart';

/// Result of parsing a document: normalized plain text plus structure metadata.
class ExtractedDocument {
  final String plainText;
  final int? pageCount;
  final bool hasStructure; // headings detected

  const ExtractedDocument({
    required this.plainText,
    this.pageCount,
    this.hasStructure = false,
  });
}

/// Abstraction every format parser implements. Adding a format = adding a
/// class here + one registry entry; nothing else in the app changes.
abstract class DocumentParser {
  DocFormat get format;

  /// Extracts normalized plain text from the file at [path].
  ///
  /// Implementations must throw [ParseException] (or a subclass) with a
  /// user-actionable message when extraction is impossible.
  Future<ExtractedDocument> parse(String path);
}

/// Resolves a [DocumentParser] for a given [DocFormat].
class ParserRegistry {
  final Map<DocFormat, DocumentParser> _parsers;

  ParserRegistry(this._parsers);

  /// The default registry with every supported format wired in.
  static ParserRegistry create() => ParserRegistry({
        DocFormat.pdf: const PdfParser(),
        DocFormat.txt: const TxtParser(),
        DocFormat.markdown: const MarkdownParser(),
        DocFormat.docx: const DocxParser(),
        // V2 formats — parsers land incrementally:
        DocFormat.pptx: const PlannedParser(DocFormat.pptx),
        DocFormat.csv: const CsvParser(),
        DocFormat.xlsx: const PlannedParser(DocFormat.xlsx),
        DocFormat.html: const HtmlParser(),
        DocFormat.json: const JsonParser(),
        DocFormat.epub: const PlannedParser(DocFormat.epub),
      });

  DocumentParser parserFor(DocFormat format) {
    final parser = _parsers[format];
    if (parser == null) {
      throw ParseException(
        '${format.label} files are not supported yet.',
        hint: 'Supported formats: PDF, TXT, Markdown, DOCX.',
      );
    }
    return parser;
  }
}

/// Placeholder for roadmap formats, so the registry knows about them but the
/// importer reports them as "planned" instead of failing obscurely.
class PlannedParser implements DocumentParser {
  final DocFormat format;
  const PlannedParser(this.format);

  @override
  Future<ExtractedDocument> parse(String path) async {
    throw ParseException(
      '${format.label} support is on the roadmap but not enabled yet.',
      hint: 'Currently supported: PDF, TXT, Markdown, DOCX.',
    );
  }
}
