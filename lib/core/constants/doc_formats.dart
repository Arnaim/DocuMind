/// Canonical names for every supported document format, plus format detection
/// helpers used by the processing pipeline.
///
/// The parser registry maps each of these to a [DocumentParser], so adding a
/// new format means adding a constant here, a parser class, and a registry
/// entry — nothing else in the app needs to change.
enum DocFormat {
  pdf,
  txt,
  markdown,
  docx,
  pptx,
  csv,
  xlsx,
  html,
  json,
  epub,
  unknown;

  /// Formats marked `v1` ship with full extraction support; the rest are
  /// registered but reported as "planned" until their parsers land.
  bool get isFullySupported => switch (this) {
        DocFormat.pdf ||
        DocFormat.txt ||
        DocFormat.markdown ||
        DocFormat.docx => true,
        _ => false,
      };

  /// Human-readable label used across the UI.
  String get label => switch (this) {
        DocFormat.pdf => 'PDF',
        DocFormat.txt => 'Plain text',
        DocFormat.markdown => 'Markdown',
        DocFormat.docx => 'Word document',
        DocFormat.pptx => 'PowerPoint',
        DocFormat.csv => 'CSV',
        DocFormat.xlsx => 'Excel',
        DocFormat.html => 'HTML',
        DocFormat.json => 'JSON',
        DocFormat.epub => 'EPUB',
        DocFormat.unknown => 'Unknown',
      };

  static DocFormat fromExtension(String extension) {
    final ext = extension.replaceAll('.', '').toLowerCase();
    return switch (ext) {
      'pdf' => DocFormat.pdf,
      'txt' || 'text' || 'log' => DocFormat.txt,
      'md' || 'markdown' => DocFormat.markdown,
      'docx' => DocFormat.docx,
      'pptx' => DocFormat.pptx,
      'csv' || 'tsv' => DocFormat.csv,
      'xlsx' || 'xlsm' => DocFormat.xlsx,
      'html' || 'htm' || 'xhtml' => DocFormat.html,
      'json' => DocFormat.json,
      'epub' => DocFormat.epub,
      _ => DocFormat.unknown,
    };
  }
}
