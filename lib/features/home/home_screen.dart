import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/collection_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/text_utils.dart';
import '../../data/models/models.dart';
import '../../state/home_provider.dart';
import '../../state/library_provider.dart';
import '../chat/chat_screen.dart';
import '../documents/document_detail_screen.dart';
import 'package:documind/features/widgets/common.dart';
import 'package:documind/features/widgets/decorations.dart';
import 'package:documind/features/widgets/motion.dart';

/// Home — a warm "research desk" greeting with colorful collection cards and
/// quick actions. Distinct hierarchy: hero → stats → actions → collections.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final home = context.watch<HomeProvider>();
    final library = context.watch<LibraryProvider>();
    final c = context.docColors;

    return Scaffold(
      body: RefreshIndicator(
        color: c.coral,
        onRefresh: () async {
          await home.refresh();
          await library.refresh();
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _Hero(home: home),
            ),
            SliverToBoxAdapter(child: _QuickActions(home: home)),
            if (library.collections.isNotEmpty)
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader('Collections'),
                    SizedBox(
                      height: 116,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: library.collections.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, i) {
                          final col = library.collections[i];
                          return FadeSlideIn(
                            delay: Duration(milliseconds: 40 * i),
                            child: CollectionCard(
                              name: col.name,
                              count: library.collectionSizes[col.id] ?? 0,
                              color: CollectionPalette.forName(col.name),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            if (home.recent.isNotEmpty) ...[
              const SliverToBoxAdapter(child: SectionHeader('Recent documents')),
              SliverList.builder(
                itemCount: home.recent.length,
                itemBuilder: (context, i) => DocumentTile(
                  document: home.recent[i],
                  onTap: () => _openDocument(context, home.recent[i]),
                ),
              ),
            ],
            if (home.recentConversations.isNotEmpty) ...[
              const SliverToBoxAdapter(child: SectionHeader('Recent conversations')),
              SliverList.builder(
                itemCount: home.recentConversations.length,
                itemBuilder: (context, i) {
                  final conv = home.recentConversations[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                    child: FadeSlideIn(
                      delay: Duration(milliseconds: 40 * i),
                      child: Material(
                        color: c.lavenderSoft.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(18),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => _openConversation(context, conv),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                const SparkleIcon(color: Color(0xFF8B6FC7), size: 14),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    conv.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.titleSmall,
                                  ),
                                ),
                                Text(
                                  formatDateLabel(conv.updatedAt),
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
          ],
        ),
      ),
    );
  }

  void _openDocument(BuildContext context, Document d) {
    context.read<LibraryProvider>().markOpened(d.id);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => DocumentDetailScreen(documentId: d.id),
    ));
  }

  void _openConversation(BuildContext context, Conversation c) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ConversationViewScreen(conversationId: c.id),
    ));
  }
}

/// Warm hero: greeting + tagline + stats pills + decorative blobs.
class _Hero extends StatelessWidget {
  final HomeProvider home;
  const _Hero({required this.home});

  @override
  Widget build(BuildContext context) {
    final c = context.docColors;
    final theme = Theme.of(context);

    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  c.coralSoft.withValues(alpha: 0.7),
                  c.surface,
                  c.lavenderSoft.withValues(alpha: 0.55),
                ],
              ),
            ),
          ),
        ),
        const Positioned(
          top: -30,
          right: -20,
          child: CornerBlob(color: Color(0x228B6FC7), size: 170),
        ),
        Positioned(
          top: 70,
          right: 60,
          child: SparkleIcon(color: c.gold.withValues(alpha: 0.5), size: 14),
        ),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_greeting(), style: theme.textTheme.bodySmall),
                const SizedBox(height: 4),
                Text(
                  'Your knowledge,\norganized.',
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    _StatPill(
                      value: '${home.documentCount}',
                      label: home.documentCount == 1 ? 'document' : 'documents',
                      color: c.coral,
                      background: c.coralSoft,
                    ),
                    const SizedBox(width: 10),
                    _StatPill(
                      value: '${home.collectionCount}',
                      label: 'collections',
                      color: c.lavender,
                      background: c.lavenderSoft,
                    ),
                    const SizedBox(width: 10),
                    _StatPill(
                      value: '${home.messageCount}',
                      label: 'AI answers',
                      color: c.mint,
                      background: c.mintSoft,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'GOOD MORNING';
    if (hour < 18) return 'GOOD AFTERNOON';
    return 'GOOD EVENING';
  }
}

class _StatPill extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  final Color background;

  const _StatPill({
    required this.value,
    required this.label,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: background.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color)),
          const SizedBox(width: 5),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// Quick actions: Add (coral, prominent), Search (lavender), Ask AI (mint).
class _QuickActions extends StatelessWidget {
  final HomeProvider home;
  const _QuickActions({required this.home});

  @override
  Widget build(BuildContext context) {
    final c = context.docColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: _BigAction(
              icon: Icons.post_add_rounded,
              label: 'Add documents',
              color: c.coral,
              background: c.coral,
              foreground: c.onAccent,
              onTap: () => _addDocuments(context),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _BigAction(
              icon: Icons.search_rounded,
              label: 'Search',
              color: c.lavender,
              background: c.lavenderSoft,
              onTap: () => DefaultTabController.maybeOf(context)?.animateTo(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _BigAction(
              icon: Icons.auto_awesome_rounded,
              label: 'Ask AI',
              color: c.mint,
              background: c.mintSoft,
              onTap: () => DefaultTabController.maybeOf(context)?.animateTo(3),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addDocuments(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'txt', 'md', 'docx'],
      allowMultiple: true,
    );
    if (result == null || !context.mounted) return;
    final paths = result.paths.whereType<String>().toList();
    if (paths.isEmpty) return;
    if (context.mounted) {
      final count = await context.read<LibraryProvider>().importPickedFiles(paths);
      if (context.mounted) {
        await context.read<HomeProvider>().refresh();
        if (count > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Importing $count document${count == 1 ? '' : 's'}…')),
          );
        }
      }
    }
  }
}

class _BigAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color background;
  final Color? foreground;
  final VoidCallback onTap;

  const _BigAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.background,
    this.foreground,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Icon(icon, color: foreground ?? color, size: 24),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: foreground ?? color,
                      fontSize: 12,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Colorful collection card with its own tinted identity.
class CollectionCard extends StatelessWidget {
  final String name;
  final int count;
  final Color color;

  const CollectionCard({
    super.key,
    required this.name,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 150,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.folder_rounded, color: color, size: 19),
          ),
          const Spacer(),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 2),
          Text(
            '$count document${count == 1 ? '' : 's'}',
            style: theme.textTheme.bodySmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
