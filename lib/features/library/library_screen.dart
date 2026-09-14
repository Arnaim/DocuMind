import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/datasources/library_datasource.dart' show DocumentSort;
import '../../data/models/models.dart';
import '../../state/home_provider.dart';
import '../../state/library_provider.dart';
import '../collections/collections_screen.dart';
import '../documents/document_detail_screen.dart';
import '../widgets/common.dart';

/// The document-management surface: import, filter, sort, favorites,
/// collections — with the coral "Add documents" button as a signature.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _searchController = TextEditingController();
  DocumentSort _sort = DocumentSort.recent;
  bool _favoritesOnly = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      context.read<LibraryProvider>().refreshWithFilter(
            query: _searchController.text,
            favoritesOnly: _favoritesOnly,
            sort: _sort,
          );
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final docs = library.documents;
    final c = context.docColors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        actions: [
          IconButton(
            tooltip: 'Favorites only',
            onPressed: () {
              setState(() => _favoritesOnly = !_favoritesOnly);
              library.refreshWithFilter(
                query: _searchController.text,
                favoritesOnly: _favoritesOnly,
                sort: _sort,
              );
            },
            icon: Icon(
              _favoritesOnly ? Icons.star_rounded : Icons.star_border_rounded,
              color: _favoritesOnly ? c.pink : null,
            ),
          ),
          PopupMenuButton<DocumentSort>(
            tooltip: 'Sort',
            icon: const Icon(Icons.sort_rounded),
            onSelected: (sort) {
              setState(() => _sort = sort);
              library.refreshWithFilter(
                query: _searchController.text,
                favoritesOnly: _favoritesOnly,
                sort: sort,
              );
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: DocumentSort.recent, child: Text('Recently imported')),
              PopupMenuItem(value: DocumentSort.lastOpened, child: Text('Recently opened')),
              PopupMenuItem(value: DocumentSort.title, child: Text('Title A–Z')),
              PopupMenuItem(value: DocumentSort.size, child: Text('File size')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _importFiles(context),
        icon: const Icon(Icons.post_add_rounded),
        label: const Text('Add documents'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Filter by title…',
                prefixIcon: const Icon(Icons.filter_alt_rounded, size: 20),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () => _searchController.clear(),
                      ),
              ),
            ),
          ),
          Expanded(
            child: library.loading && docs.isEmpty
                ? ListView(
                    padding: const EdgeInsets.all(20),
                    children: List.generate(
                      5,
                      (_) => const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: SkeletonBox(height: 76),
                      ),
                    ),
                  )
                : docs.isEmpty
                    ? EmptyState(
                        icon: Icons.auto_stories_rounded,
                        title: 'A shelf waiting for books',
                        subtitle:
                            'Import a PDF, Word file, Markdown or plain text document. Everything stays on this device.',
                        action: FilledButton.icon(
                          onPressed: () => _importFiles(context),
                          icon: const Icon(Icons.post_add_rounded),
                          label: const Text('Add documents'),
                        ),
                      )
                    : RefreshIndicator(
                        color: c.coral,
                        onRefresh: library.refresh,
                        child: ListView.builder(
                          padding: const EdgeInsets.only(bottom: 100, top: 4),
                          itemCount: docs.length,
                          itemBuilder: (context, i) {
                            final doc = docs[i];
                            final progress = library.progressFor(doc.id);
                            return DocumentTile(
                              document: doc,
                              onTap: () => _open(context, doc),
                              trailing: _trailing(context, doc, progress),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget? _trailing(
      BuildContext context, Document doc, PipelineProgress? progress) {
    if (progress != null && progress.error == null && progress.progress < 1) {
      return SizedBox(
        width: 84,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(progress.stage,
                style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.progress,
                minHeight: 5,
              ),
            ),
          ],
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        StatusChip(status: doc.status),
        PopupMenuButton<String>(
          onSelected: (action) => _onAction(context, action, doc),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'open', child: Text('Open')),
            PopupMenuItem(value: 'rename', child: Text('Rename')),
            PopupMenuItem(value: 'move', child: Text('Collections…')),
            PopupMenuItem(value: 'reprocess', child: Text('Re-process')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ],
    );
  }

  Future<void> _open(BuildContext context, Document doc) async {
    await context.read<LibraryProvider>().markOpened(doc.id);
    if (context.mounted) {
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => DocumentDetailScreen(documentId: doc.id),
      ));
    }
    if (context.mounted) {
      await context.read<HomeProvider>().refresh();
    }
  }

  Future<void> _importFiles(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'txt', 'md', 'docx'],
      allowMultiple: true,
    );
    if (result == null) return;
    final paths = result.paths.whereType<String>().toList();
    if (paths.isEmpty) return;
    if (context.mounted) {
      final count = await context.read<LibraryProvider>().importPickedFiles(paths);
      if (context.mounted && count > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Importing $count document${count == 1 ? '' : 's'}…')),
        );
      }
    }
  }

  Future<void> _onAction(
      BuildContext context, String action, Document doc) async {
    final library = context.read<LibraryProvider>();
    switch (action) {
      case 'open':
        await _open(context, doc);
      case 'rename':
        _renameDialog(context, library, doc);
      case 'move':
        showMoveToCollectionSheet(context, doc);
      case 'reprocess':
        await library.reprocess(doc.id);
      case 'delete':
        _confirmDelete(context, library, doc);
    }
  }

  void _renameDialog(
      BuildContext context, LibraryProvider library, Document doc) {
    final controller = TextEditingController(text: doc.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename document'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Title'),
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

  void _confirmDelete(
      BuildContext context, LibraryProvider library, Document doc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete document?'),
        content: Text(
          '"${doc.title}" and its index will be removed from this device. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.docColors.danger,
            ),
            onPressed: () {
              library.deleteDocument(doc.id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
