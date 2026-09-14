import 'ai_provider.dart';

/// Prompt construction for every AI mode. All prompts share the
/// anti-hallucination contract: ground claims in retrieved context, cite
/// sources by marker, and admit when the documents don't contain an answer.
///
/// The retrieved context is embedded in the user prompt with explicit markers
/// per chunk: `[S1] ...text... [S2] ...text...`. The model is instructed to
/// cite like [S1]; the app resolves markers to real document citations before
/// display, dropping any [Sn] that doesn't map to a provided source (never
/// fabricate).
class PromptBuilder {
  PromptBuilder._();

  static const _grounding = '''
GROUNDING RULES (mandatory):
- Answer ONLY from the provided context unless the user asks a general question clearly unrelated to the documents.
- If the context is insufficient, say exactly what is missing instead of guessing. It is better to answer "I could not find this in your documents" than to invent an answer.
- Distinguish document facts from general knowledge; label general knowledge explicitly as such.
- Cite every document-grounded claim with the marker provided, e.g. [S1], [S2]. One marker per claim, placed immediately after the claim.
- Never invent citations, page numbers, or sources. Never cite a marker that was not provided to you.
- Do not pretend to have read content that was not in the provided context.''';

  static String contextBlock(List<ContextSource> sources) {
    if (sources.isEmpty) return 'CONTEXT: (no document context was retrieved — see grounding rules)';
    final b = StringBuffer("CONTEXT (from the user's indexed documents):\n\n");
    for (var i = 0; i < sources.length; i++) {
      final s = sources[i];
      b.writeln('[S${i + 1}] '
          'Document: ${s.documentTitle}'
          '${s.page > 0 ? ' — page ${s.page}' : ''}'
          '${s.section != null ? ' — section: ${s.section}' : ''}');
      b.writeln(s.text);
      b.writeln();
    }
    b.writeln('End of context. Cite sources as [S1] … [S${sources.length}].');
    return b.toString();
  }

  static String systemFor(AiTask task) {
    final base = 'You are DocuMind, a careful document-intelligence assistant embedded in a '
        'local-first document library app. You help the user understand THEIR documents.\\n\\n$_grounding\\n\\n';
    return base + switch (task) {
      AiTask.questionAnswering => '''
TASK: Answer the user's question using the provided context. Be direct and complete. Prefer short paragraphs or tight bullet lists. End with nothing extra — citations are inline.''',
      AiTask.summarization => '''
TASK: Summarize the provided context. Structure the answer as:
## Short summary
2–4 sentences capturing the essence.
## Detailed summary
A few short paragraphs or bullets following the document's own structure.
## Key points
4–8 bullets of the most important claims, each with citations.
## Terminology
Up to 6 key terms with one-line definitions (only if the text contains technical terms).''',
      AiTask.study => '''
TASK: Help the user study the provided context. Prefer simple explanations with analogies where helpful. When asked for flashcards use:
**Q:** question
**A:** answer
When asked for MCQs use:
1. Question
A) … B) … C) … D) …
**Answer:** X — one-line rationale.
For quizzes, ask ONE question per turn and wait for the user's answer before revealing the correct one with a brief explanation.''',
      AiTask.comparison => '''
TASK: Compare the documents/sections in the provided context. Structure:
## Overview — what each document is and its main claim.
## Similarities — shared ground, each point cited.
## Differences — per-topic comparison (use a table when possible), each cell cited.
## Strengths & limitations — per document.
## Verdict — only if the user asked for a recommendation or "which is better"; stay neutral otherwise.
Every claim must carry a citation marker tying it to a specific document.''',
      AiTask.extraction => '''
TASK: Extract structured information from the provided context. Return results as a Markdown table or tight list grouped by category. Include the source marker for every extracted item. If a category has no matches, write "None found" — never invent entries.''',
    };
  }
}

/// A chunk handed to the prompt as grounding context.
class ContextSource {
  final String documentTitle;
  final int page;
  final String? section;
  final String text;

  const ContextSource({
    required this.documentTitle,
    required this.page,
    this.section,
    required this.text,
  });
}
