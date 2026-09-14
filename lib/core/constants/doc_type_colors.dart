import 'package:flutter/material.dart';
import 'doc_formats.dart';

/// Per-format accent identities: PDF→coral, Markdown→lavender, DOCX→plum-ish
/// purple, TXT→mint, CSV/JSON→gold, HTML→pink. Cards stay neutral; these
/// colors drive icons, badges and accent bars.
class DocTypeColors {
  DocTypeColors._();

  static Color accent(DocFormat format) => switch (format) {
        DocFormat.pdf => const Color(0xFFE8604C), // coral
        DocFormat.markdown => const Color(0xFF8B6FC7), // lavender
        DocFormat.docx => const Color(0xFF6C5CE7), // blue-purple
        DocFormat.pptx => const Color(0xFFE08A2E), // orange
        DocFormat.txt => const Color(0xFF1E8E7A), // mint
        DocFormat.csv || DocFormat.xlsx => const Color(0xFFB98214), // gold
        DocFormat.json => const Color(0xFF1E8E7A), // mint
        DocFormat.html => const Color(0xFFD2548C), // pink
        DocFormat.epub => const Color(0xFFD2548C), // pink
        DocFormat.unknown => const Color(0xFF8A7A6D), // warm gray
      };

  /// 2–3 letter badge label.
  static String badge(DocFormat format) => switch (format) {
        DocFormat.pdf => 'PDF',
        DocFormat.markdown => 'MD',
        DocFormat.docx => 'DOC',
        DocFormat.pptx => 'PPT',
        DocFormat.txt => 'TXT',
        DocFormat.csv => 'CSV',
        DocFormat.xlsx => 'XLS',
        DocFormat.json => 'JSON',
        DocFormat.html => 'WEB',
        DocFormat.epub => 'EPUB',
        DocFormat.unknown => '?',
      };
}
