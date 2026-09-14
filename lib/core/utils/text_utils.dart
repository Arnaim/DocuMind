/// Lightweight utilities for locating text, trimming snippets and formatting
/// human-readable labels. No Flutter imports — keep this pure Dart so it is
/// trivially unit-testable.
library;

/// Returns a short excerpt centered on the first occurrence of [query] in
/// [text], padded with [padding] characters on each side and ellipsised.
///
/// The excerpt is clipped to whole-word boundaries where possible so snippets
/// never start mid-word. When the query is absent, the start of the text is
/// returned instead.
String buildSnippet(String text, String query, {int padding = 80}) {
  final clean = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (clean.isEmpty) return '';
  if (query.trim().isEmpty || clean.length <= padding * 2) {
    return clean.length <= padding * 2 ? clean : '${clean.substring(0, padding * 2)}…';
  }

  final lowerText = clean.toLowerCase();
  final lowerQuery = query.trim().toLowerCase();
  final idx = lowerText.indexOf(lowerQuery);

  if (idx < 0) {
    return clean.length <= padding * 2
        ? clean
        : '${clean.substring(0, padding * 2)}…';
  }

  var start = (idx - padding).clamp(0, clean.length);
  var end = (idx + query.trim().length + padding).clamp(0, clean.length);

  // Snap to word boundaries so snippets look intentional.
  const wordChars = ' \t\n';
  while (start > 0 && !wordChars.contains(clean[start - 1])) {
    start--;
  }
  while (end < clean.length && !wordChars.contains(clean[end])) {
    end++;
  }

  final prefix = start > 0 ? '…' : '';
  final suffix = end < clean.length ? '…' : '';
  return '$prefix${clean.substring(start, end)}$suffix';
}

/// Case-insensitive count of how many times [query] appears in [text].
int countOccurrences(String text, String query) {
  if (query.isEmpty) return 0;
  final escaped = RegExp.escape(query);
  return RegExp(escaped, caseSensitive: false).allMatches(text).length;
}

/// Formats a byte count as a compact, human-readable size.
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

/// Formats an ISO-8601 timestamp as a short, locale-neutral date.
String formatDateLabel(DateTime time) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(time.year, time.month, time.day);
  final diff = today.difference(day).inDays;

  String base;
  if (diff == 0) {
    base = 'Today';
  } else if (diff == 1) {
    base = 'Yesterday';
  } else if (diff > 1 && diff < 7) {
    base = '$diff days ago';
  } else {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    base = '${months[time.month - 1]} ${time.day}, ${time.year}';
  }
  return base;
}

/// Strips characters that break FTS5 query syntax (quotes, operators) and
/// returns a safe prefix-match query like `atten* OR neur*`.
///
/// Terms are joined with OR — FTS5's implicit AND would drop results when a
/// single stop word is absent from a chunk. BM25 then ranks chunks matching
/// more (and rarer) terms higher, which behaves like a proper search engine.
String sanitizeFtsQuery(String query) {
  final words = query
      .replaceAll(RegExp(r'[^\w\s]'), ' ')
      .split(RegExp(r'\s+'))
      .map((w) => w.trim())
      .where((w) => w.isNotEmpty)
      .take(12)
      .map((w) => '${w}*')
      .toList();
  return words.join(' OR ');
}
