import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../ai/ai_provider.dart';
import '../../ai/ai_service_factory.dart';
import '../../ai/rag_service.dart';
import '../../core/errors/app_exceptions.dart';
import '../../data/datasources/library_datasource.dart';
import '../../data/models/models.dart';
import '../../state/chat_provider.dart';
import '../../state/library_provider.dart';
import '../../state/settings_provider.dart';
import '../chat/chat_screen.dart';
import '../widgets/common.dart';

/// Multi-document AI tools: Compare documents, and the résumé-vs-job
/// scenario. Both retrieve per-document context and force source-tagged
/// output through the RAG pipeline.
class CompareToolsScreen extends StatefulWidget {
  const CompareToolsScreen({super.key});

  @override
  State<CompareToolsScreen> createState() => _CompareToolsScreenState();
}

class _CompareToolsScreenState extends State<CompareToolsScreen> {
  final Set<String> _selected = {};
  bool _running = false;
  String? _error;
  RagAnswer? _result;
  AiTask _mode = AiTask.comparison;

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final docs = library.documents
        .where((d) => d.status == ProcessingStatus.ready)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Compare & analyze')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                SegmentedButton<AiTask>(
                  segments: const [
                    ButtonSegment(
                        value: AiTask.comparison,
                        label: Text('Compare'),
                        icon: Icon(Icons.compare_arrows)),
                    ButtonSegment(
                        value: AiTask.extraction,
                        label: Text('Résumé vs job'),
                        icon: Icon(Icons.work_outline)),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (s) => setState(() => _mode = s.first),
                ),
              ],
            ),
          ),
          Expanded(
            child: docs.isEmpty
                ? const EmptyState(
                    icon: Icons.checklist,
                    title: 'No ready documents',
                    subtitle:
                        'Import and finish indexing at least two documents (one for résumé analysis) first.',
                  )
                : ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, i) {
                      final d = docs[i];
                      final selected = _selected.contains(d.id);
                      return CheckboxListTile(
                        value: selected,
                        title: Text(d.title),
                        subtitle: Text(d.format.label),
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            _selected.add(d.id);
                          } else {
                            _selected.remove(d.id);
                          }
                        }),
                      );
                    },
                  ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (_result != null) _resultCard(context, _result!),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              onPressed: _selected.length >= 2 && !_running
                  ? () => _run(context)
                  : null,
              icon: _running
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.auto_awesome),
              label: Text(_mode == AiTask.comparison
                  ? 'Compare ${_selected.length} documents'
                  : 'Analyze résumé against job description'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _run(BuildContext context) async {
    setState(() {
      _running = true;
      _error = null;
      _result = null;
    });
    try {
      final settings = context.read<SettingsProvider>();
      final library = context.read<LibraryProvider>();
      final factory = AiServiceFactory(LibraryDatasource());
      final rag = factory.createRagService(settings.aiConfig);
      if (rag == null) {
        throw AiProviderException(
            'The AI provider is not configured.',
            hint: 'Add an API key in Settings first.');
      }

      final docs = (await Future.wait(
              _selected.map((id) => library.getDocument(id))))
          .whereType<Document>()
          .toList();
      final titles = docs.map((d) => d.title).join('", "');

      final (question, instruction) = _mode == AiTask.comparison
          ? (
              'Compare these documents: "$titles"',
              'Follow the comparison structure from your instructions. Tag every claim with the document it comes from using its [Sn] marker.',
            )
          : (
              'Analyze the résumé against the job description. Identify: overall match estimate with reasoning, strong matches, potential gaps, and concrete suggestions. Tag every claim with its [Sn] source marker.',
              'One of the selected documents is a résumé/CV and another is a job description. If you cannot tell which is which, say so instead of guessing.',
            );

      final answer = await rag.answer(
        question: question,
        scope: RagScope.documents(_selected.toList()),
        config: settings.aiConfig,
        task: _mode,
        instructionOverride: instruction,
      );
      setState(() => _result = answer);
    } on DocuMindException catch (e) {
      setState(() => _error = e.hint == null ? e.message : '${e.message}\n${e.hint}');
    } catch (e) {
      setState(() => _error = 'Analysis failed. Please try again.');
    } finally {
      setState(() => _running = false);
    }
  }

  Widget _resultCard(BuildContext context, RagAnswer answer) {
    final chat = context.read<ChatProvider>();
    return Expanded(
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: ListView(
            children: [
              SelectableText(answer.answer,
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 12),
              if (answer.citations.isNotEmpty) ...[
                const Divider(),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: answer.citations
                      .map((c) => CitationChip(citation: c))
                      .toList(),
                ),
              ],
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  chat.setScope(ChatScope.documents(
                    'Comparison',
                    answer.usedChunks.map((r) => r.document.id).toSet().toList(),
                  ));
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const ChatWorkspaceScreen()));
                },
                child: const Text('Continue in chat'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
