import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../state/search_provider.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';

/// Search — a central feature, not a text field: large rounded input with a
/// lavender focus glow, filter chips, and result cards with soft-highlighted
/// matched text.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  String _typeFilter = 'All';

  static const _filters = ['All', 'PDF', 'MD', 'DOC', 'TXT'];

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final search = context.watch<SearchProvider>();
    final c = context.docColors;

    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: Column(
        children: [
          // Hero search field.
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: _focus.hasFocus
                    ? [
                        BoxShadow(
                          color: c.lavender.withValues(alpha: 0.25),
                          blurRadius: 18,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _run(context),
                style: Theme.of(context).textTheme.bodyLarge,
                decoration: InputDecoration(
                  hintText: 'Search your knowledge…',
                  prefixIcon: Icon(Icons.search_rounded,
                      size: 24, color: c.lavender),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.arrow_forward_rounded, color: c.coral),
                    onPressed: () => _run(context),
                  ),
                  filled: true,
                  fillColor: c.surfaceWarm,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: c.outline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: c.outline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: c.lavender, width: 1.6),
                  ),
                ),
              ),
            ),
          ),
          // Filter chips.
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              children: _filters.map((f) {
                final selected = _typeFilter == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(f),
                    selected: selected,
                    showCheckmark: false,
                    onSelected: (_) {
                      setState(() => _typeFilter = f);
                      _run(context);
                    },
                    labelStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: selected ? c.onAccent : c.plum,
                          fontWeight: FontWeight.w700,
                        ),
                    selectedColor: c.lavender,
                    backgroundColor: c.surfaceWarm,
                    side: BorderSide(
                        color: selected ? c.lavender : c.outline),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          if (search.searching)
            LinearProgressIndicator(
              minHeight: 2,
              color: c.lavender,
            ),
          Expanded(child: _buildResults(context, search)),
        ],
      ),
    );
  }

  void _run(BuildContext context) {
    FocusScope.of(context).unfocus();
    context.read<SearchProvider>().search(_controller.text);
  }

  Widget _buildResults(BuildContext context, SearchProvider search) {
    final c = context.docColors;
    if (search.lastQuery.isEmpty) {
      return EmptyState(
        icon: Icons.manage_search_rounded,
        title: 'Search across everything',
        subtitle:
            'Find any phrase in every indexed document — with page numbers and context. Runs fully offline.',
        accent: c.mint,
      );
    }

    if (search.hits.isEmpty && !search.searching) {
      return EmptyState(
        icon: Icons.search_off_rounded,
        title: 'Nothing found',
        subtitle:
            'Try fewer words or different spelling — and check the document finished indexing.',
        accent: c.gold,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 24),
      itemCount: search.hits.length,
      itemBuilder: (context, i) {
        final hit = search.hits[i];
        if (_typeFilter != 'All' &&
            !hit.document.format.name.toUpperCase().contains(_typeFilter)) {
          return const SizedBox.shrink();
        }
        return FadeSlideIn(
          delay: Duration(milliseconds: 30 * (i < 8 ? i : 8)),
          child: _ResultCard(
            hit: hit,
            query: search.lastQuery,
            onTap: () => _showChunk(context, hit),
          ),
        );
      },
    );
  }

  void _showChunk(BuildContext context, SearchHit hit) {
    final c = context.docColors;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (ctx, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(22),
          children: [
            Text(hit.document.title, style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Page ${hit.chunk.pageNumber}'
              '${hit.chunk.section != null ? ' · ${hit.chunk.section}' : ''}',
              style: Theme.of(ctx).textTheme.labelMedium?.copyWith(color: c.coral),
            ),
            const Divider(height: 26),
            Text(hit.chunk.text, style: Theme.of(ctx).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

/// Result card with the matched text softly highlighted (gold wash).
class _ResultCard extends StatelessWidget {
  final SearchHit hit;
  final String query;
  final VoidCallback onTap;

  const _ResultCard({
    required this.hit,
    required this.query,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.docColors;
    final theme = Theme.of(context);
    // FTS snippet marks matches with ▸ … ◂ — render them highlighted.
    final parts = hit.snippet.split(RegExp('[▸◂]'));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Material(
        color: c.surfaceWarm,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: c.outline.withValues(alpha: 0.8)),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.description_rounded,
                        size: 17, color: c.coral),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        hit.document.title,
                        style: theme.textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: c.mintSoft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Page ${hit.chunk.pageNumber}',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: c.mint),
                      ),
                    ),
                  ],
                ),
                if (hit.chunk.section != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    hit.chunk.section!,
                    style: theme.textTheme.labelSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 10),
                _HighlightedSnippet(parts: parts, query: query),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HighlightedSnippet extends StatelessWidget {
  final List<String> parts;
  final String query;

  const _HighlightedSnippet({required this.parts, required this.query});

  @override
  Widget build(BuildContext context) {
    final c = context.docColors;
    final base = Theme.of(context).textTheme.bodyMedium;
    final spans = <TextSpan>[];
    for (var i = 0; i < parts.length; i++) {
      if (i > 0) {
        // Odd segments sat between markers → matched text.
        spans.add(TextSpan(
          text: parts[i],
          style: TextStyle(
            backgroundColor: c.goldSoft,
            color: c.plum,
            fontWeight: FontWeight.w700,
          ),
        ));
      } else {
        spans.add(TextSpan(text: parts[i]));
      }
    }
    return RichText(
      text: TextSpan(children: spans, style: base),
      maxLines: 4,
      overflow: TextOverflow.ellipsis,
    );
  }
}
