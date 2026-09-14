import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/text_utils.dart';
import '../../data/models/models.dart';
import '../../state/chat_provider.dart';
import '../chat/chat_screen.dart' show ChatWorkspaceScreen;
import '../../state/library_provider.dart';
import '../collections/collections_screen.dart';
import '../widgets/common.dart';
import '../widgets/decorations.dart';

/// Per-document workspace: metadata, processing status, management actions
/// and entry points into AI workflows scoped to this document.
class DocumentDetailScreen extends StatefulWidget {
  final String documentId;

  const DocumentDetailScreen({super.key, required this.documentId});

  @override
  State<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<DocumentDetailScreen> {
  @override
  void initState() {
    super.initState();
    context.read<LibraryProvider>().markOpened(widget.documentId);
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final docOrNull = library.documents
        .where((d) => d.id == widget.documentId)
        .cast<Document?>()
        .firstOrNull;

    final doc = docOrNull;
    if (doc == null) {
      // Deleted while open (or still loading) — leave gracefully.
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final theme = Theme.of(context);
    final c = context.docColors;
    final progress = library.progressFor(doc.id);

    return Scaffold(
      appBar: AppBar(
        title: Text(doc.title),
        actions: [
          IconButton(
            tooltip: doc.isFavorite ? 'Remove favorite' : 'Add favorite',
            icon: Icon(doc.isFavorite ? Icons.star : Icons.star_border),
            onPressed: () =>
                library.setFavorite(doc.id, !doc.isFavorite),
          ),
          PopupMenuButton<String>(
            onSelected: (a) => _onAction(context, a, doc),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'rename', child: Text('Rename')),
              PopupMenuItem(value: 'collections', child: Text('Collections…')),
              PopupMenuItem(value: 'reprocess', child: Text('Re-process')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (progress != null) ...[
            _ProcessingCard(progress: progress),
            const SizedBox(height: 12),
          ],
          if (doc.status == ProcessingStatus.failed && doc.errorMessage != null) ...[
            Card(
              color: c.coralSoft,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(Icons.error_rounded, color: c.coral),
                    const SizedBox(width: 10),
                    Expanded(child: Text(doc.errorMessage!)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // AI actions scoped to this document.
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: IconBadge(
                    icon: Icons.auto_awesome_rounded,
                    color: c.lavender,
                    background: c.lavenderSoft,
                  ),
                  title: const Text('Ask AI about this document'),
                  subtitle: const Text('Grounded answers with page citations'),
                  onTap: () => _openChat(context, doc),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: IconBadge(
                    icon: Icons.summarize_rounded,
                    color: c.mint,
                    background: c.mintSoft,
                  ),
                  title: const Text('Summarize'),
                  subtitle: const Text('Short + detailed summary, key points'),
                  onTap: () => _openChat(context, doc, prompt: 'Summarize this document.'),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: IconBadge(
                    icon: Icons.school_rounded,
                    color: c.gold,
                    background: c.goldSoft,
                  ),
                  title: const Text('Study'),
                  subtitle: const Text('Explanations, flashcards, MCQs, quiz'),
                  onTap: () => _openChat(context, doc,
                      prompt: 'Create study notes and flashcards from this document.'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Metadata.
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Details', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 12),
                  _DetailRow('Format', doc.format.label),
                  _DetailRow('File', doc.fileName),
                  _DetailRow('Size', formatBytes(doc.fileSizeBytes)),
                  _DetailRow('Pages', '${doc.pageCount}'),
                  _DetailRow('Characters', '${doc.charCount}'),
                  _DetailRow('Words', '~${doc.wordCount}'),
                  _DetailRow('Imported', formatDateLabel(doc.importedAt)),
                  if (doc.lastOpenedAt != null)
                    _DetailRow('Last opened', formatDateLabel(doc.lastOpenedAt!)),
                  const SizedBox(height: 8),
                  StatusChip(status: doc.status),
                  if (doc.hasEmbeddings) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Semantic index available',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openChat(BuildContext context, Document doc, {String? prompt}) {
    final chat = context.read<ChatProvider>();
    chat.setScope(ChatScope.single(doc));
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const ChatWorkspaceScreen(),
    ));
    if (prompt != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        chat.send(prompt);
      });
    }
  }

  Future<void> _onAction(BuildContext context, String action, Document doc) async {
    final library = context.read<LibraryProvider>();
    switch (action) {
      case 'rename':
        {
          final controller = TextEditingController(text: doc.title);
          if (!context.mounted) return;
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Rename document'),
              content: TextField(
                controller: controller,
                autofocus: true,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final t = controller.text.trim();
                    if (t.isNotEmpty) library.renameDocument(doc.id, t);
                    Navigator.pop(ctx);
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
          );
        }
      case 'collections':
        showMoveToCollectionSheet(context, doc);
      case 'reprocess':
        await library.reprocess(doc.id);
      case 'delete':
        await library.deleteDocument(doc.id);
        if (context.mounted) Navigator.of(context).pop();
    }
  }
}

class _ProcessingCard extends StatelessWidget {
  final PipelineProgress progress;
  const _ProcessingCard({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Text(progress.stage),
                const Spacer(),
                Text('${(progress.progress * 100).round()}%'),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(value: progress.progress),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(value, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
