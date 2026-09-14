import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/collection_palette.dart';
import '../../data/models/models.dart';
import '../../state/library_provider.dart';
import '../documents/document_detail_screen.dart';
import '../widgets/common.dart';

/// Reusable colored collection chip (Home dashboard + collection views).
class CollectionChip extends StatelessWidget {
  final Collection collection;
  final int size;
  final VoidCallback? onTap;

  const CollectionChip({
    super.key,
    required this.collection,
    required this.size,
    this.onTap,
  });

  Color get color => CollectionPalette.forName(collection.name);

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(Icons.folder, size: 16, color: color),
      label: Text('${collection.name} · $size'),
      onPressed: onTap,
    );
  }
}

/// Shows the create/rename dialog; returns the entered name or null.
Future<String?> showCreateCollectionDialog(BuildContext context,
    {String? initial}) async {
  final controller = TextEditingController(text: initial ?? '');
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(initial == null ? 'New collection' : 'Rename collection'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Name'),
        onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

/// Bottom sheet to add/remove a document from collections.
Future<void> showMoveToCollectionSheet(BuildContext context, Document doc) async {
  final library = context.read<LibraryProvider>();
  final current = await library.collectionIdsForDocument(doc.id);
  if (!context.mounted) return;

  await showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final collections = library.collections;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Collections for "${doc.title}"',
                    style: Theme.of(ctx).textTheme.titleSmall),
              ),
              if (collections.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No collections yet. Create one first.'),
                ),
              ...collections.map((c) {
                final selected = current.contains(c.id);
                return CheckboxListTile(
                  value: selected,
                  title: Text(c.name),
                  onChanged: (value) {
                    library.moveDocument(doc.id, c.id, value == true);
                    setState(() {
                      if (value == true) {
                        current.add(c.id);
                      } else {
                        current.remove(c.id);
                      }
                    });
                  },
                );
              }),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('New collection'),
                onTap: () async {
                  final name = await showCreateCollectionDialog(ctx);
                  if (name != null && name.isNotEmpty) {
                    await library.createCollection(name);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
            ],
          ),
        );
      },
    ),
  );
}

/// Simple standalone collections manager (reachable from Home).
class CollectionsScreen extends StatelessWidget {
  const CollectionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final collections = library.collections;

    return Scaffold(
      appBar: AppBar(title: const Text('Collections')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final name = await showCreateCollectionDialog(context);
          if (name != null && name.isNotEmpty && context.mounted) {
            await library.createCollection(name);
          }
        },
        child: const Icon(Icons.add),
      ),
      body: collections.isEmpty
          ? const EmptyState(
              icon: Icons.folder_off_outlined,
              title: 'No collections',
              subtitle:
                  'Collections group related documents — "University", "Work", "Research" — and can scope AI questions.',
            )
          : ListView(
              children: collections
                  .map((c) => ListTile(
                        leading: Icon(Icons.folder,
                            color: CollectionChip(
                              collection: c,
                              size: 0,
                            ).color),
                        title: Text(c.name),
                        subtitle: Text(
                            '${library.collectionSizes[c.id] ?? 0} documents'),
                        trailing: PopupMenuButton<String>(
                          onSelected: (a) async {
                            if (a == 'rename') {
                              final name = await showCreateCollectionDialog(
                                  context,
                                  initial: c.name);
                              if (name != null && name.isNotEmpty) {
                                await library.renameCollection(c.id, name);
                              }
                            } else if (a == 'delete') {
                              await library.deleteCollection(c.id);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'rename', child: Text('Rename')),
                            PopupMenuItem(value: 'delete', child: Text('Delete')),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CollectionDocumentsScreen(
                                collection: c,
                              ),
                            ),
                          );
                        },
                      ))
                  .toList(),
            ),
    );
  }
}

/// Documents inside one collection.
class CollectionDocumentsScreen extends StatelessWidget {
  final Collection collection;
  const CollectionDocumentsScreen({super.key, required this.collection});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    return FutureBuilder<List<Document>>(
      future: library.listDocumentsInCollection(collection.id),
      builder: (context, snap) {
        final docs = snap.data ?? const <Document>[];
        return Scaffold(
          appBar: AppBar(title: Text(collection.name)),
          body: docs.isEmpty
              ? const EmptyState(
                  icon: Icons.folder_open_outlined,
                  title: 'Empty collection',
                  subtitle:
                      'Move documents here from the Library screen via the ⋮ menu.',
                )
              : ListView(
                  children: docs
                      .map((d) => DocumentTile(
                            document: d,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    DocumentDetailScreen(documentId: d.id),
                              ),
                            ),
                          ))
                      .toList(),
                ),
        );
      },
    );
  }
}