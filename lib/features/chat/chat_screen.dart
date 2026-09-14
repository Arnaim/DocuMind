import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../../state/chat_provider.dart';
import '../../state/library_provider.dart';
import '../compare/compare_tools_screen.dart';
import '../widgets/decorations.dart';
import '../widgets/motion.dart';

/// The AI workspace. Not a ChatGPT clone: AI answers live in soft lavender
/// cards signed "✦ DocuMind", user messages in warm cream bubbles, sources
/// in mint/purple pills.
class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ChatAppBar(),
      body: const Column(
        children: [
          ScopeSelector(),
          Expanded(child: MessageList()),
        ],
      ),
      bottomNavigationBar: ChatInputBar(),
    );
  }
}

class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ChatAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    return AppBar(
      title: Text(chat.activeConversation?.title ?? 'Ask your documents'),
      actions: [
        IconButton(
          tooltip: 'Compare documents',
          icon: const Icon(Icons.compare_arrows_rounded),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CompareToolsScreen()),
          ),
        ),
        IconButton(
          tooltip: 'New conversation',
          icon: const Icon(Icons.add_comment_rounded),
          onPressed: () => chat.startNewConversation(),
        ),
        IconButton(
          tooltip: 'History',
          icon: const Icon(Icons.history_rounded),
          onPressed: () => _showHistory(context),
        ),
      ],
    );
  }

  void _showHistory(BuildContext context) {
    final chat = context.read<ChatProvider>();
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Conversations',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            ...chat.conversations.map(
              (c) => ListTile(
                leading: const SparkleIcon(color: Color(0xFF8B6FC7), size: 14),
                title: Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(c.updatedAt.toLocal().toString().substring(0, 16)),
                onTap: () {
                  Navigator.pop(ctx);
                  chat.openConversation(c);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Scope picker: entire library / collections as colorful chips.
class ScopeSelector extends StatelessWidget {
  const ScopeSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final library = context.watch<LibraryProvider>();
    final c = context.docColors;

    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text('Entire library'),
              selected: chat.scope.entireLibrary,
              showCheckmark: false,
              onSelected: (_) => chat.setScope(const ChatScope.library()),
              selectedColor: c.coral,
              backgroundColor: c.surfaceWarm,
              labelStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: chat.scope.entireLibrary ? c.onAccent : c.plum,
                  ),
              side: BorderSide(
                  color: chat.scope.entireLibrary ? c.coral : c.outline),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
          ...library.collections.map(
            (col) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(col.name),
                selected: !chat.scope.entireLibrary &&
                    chat.scope.label == col.name,
                showCheckmark: false,
                onSelected: (_) async {
                  final docs =
                      await library.listDocumentsInCollection(col.id);
                  chat.setScope(ChatScope.documents(
                    col.name,
                    docs.map((d) => d.id).toList(),
                  ));
                },
                selectedColor: c.lavender,
                backgroundColor: c.lavenderSoft.withValues(alpha: 0.5),
                labelStyle: Theme.of(context).textTheme.labelSmall,
                side: BorderSide(color: c.lavender.withValues(alpha: 0.4)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MessageList extends StatelessWidget {
  const MessageList({super.key});

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final messages = chat.messages;

    if (messages.isEmpty && !chat.sending) {
      return const _ChatEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: messages.length + (chat.sending ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == messages.length) return const _TypingIndicator();
        final message = messages[i];
        return FadeSlideIn(
          key: ValueKey(message.id),
          offset: 8,
          child: message.role == MessageRole.user
              ? _UserBubble(message: message)
              : _AssistantBubble(message: message),
        );
      },
    );
  }
}

/// User message: warm cream bubble with a coral edge.
class _UserBubble extends StatelessWidget {
  final Message message;
  const _UserBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final c = context.docColors;
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        decoration: BoxDecoration(
          color: c.coralSoft,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(6),
          ),
          border: Border.all(color: c.coral.withValues(alpha: 0.25)),
        ),
        child: Text(message.content,
            style: Theme.of(context).textTheme.bodyMedium),
      ),
    );
  }
}

/// AI answer: lavender card, "✦ DocuMind" signature, mint source pills.
class _AssistantBubble extends StatelessWidget {
  final Message message;
  const _AssistantBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final c = context.docColors;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.all(16),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.94),
        decoration: BoxDecoration(
          color: c.lavenderSoft.withValues(alpha: 0.75),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(6),
            bottomRight: Radius.circular(18),
          ),
          border: Border.all(color: c.lavender.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SparkleIcon(color: c.lavender, size: 13),
                const SizedBox(width: 6),
                Text(
                  'DocuMind',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: c.lavender,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SelectableText(message.content,
                style: Theme.of(context).textTheme.bodyMedium),
            if (message.citations.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'SOURCES',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: c.lavender.withValues(alpha: 0.8),
                      letterSpacing: 1.2,
                      fontSize: 10,
                    ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: message.citations
                    .map((citation) => CitationChip(citation: citation))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Source citation pill — one of DocuMind's visual signatures:
/// [ 📄 Title · Page 4 ] in soft mint with a plum label.
class CitationChip extends StatelessWidget {
  final Citation citation;
  const CitationChip({super.key, required this.citation});

  @override
  Widget build(BuildContext context) {
    final c = context.docColors;
    return Material(
      color: c.mintSoft,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _showSource(context, citation),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.description_rounded, size: 13, color: c.mint),
              const SizedBox(width: 5),
              Text(
                '${citation.documentTitle} · Page ${citation.page}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: c.plum,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSource(BuildContext context, Citation citation) {
    final c = context.docColors;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconBadge(
                    icon: Icons.description_rounded,
                    color: c.mint,
                    background: c.mintSoft,
                    size: 17,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${citation.documentTitle} — Page ${citation.page}',
                      style: Theme.of(ctx).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              if (citation.section != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    citation.section!,
                    style: Theme.of(ctx).textTheme.labelSmall,
                  ),
                ),
              const Divider(height: 26),
              Text(
                citation.snippet.isEmpty
                    ? '(Source passage retrieved during the answer.)'
                    : citation.snippet,
                style:
                    Theme.of(ctx).textTheme.bodyMedium?.copyWith(height: 1.55),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Typing state: lavender dots card ("Reading your documents…").
class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.docColors;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.lavenderSoft.withValues(alpha: 0.75),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(6),
            bottomRight: Radius.circular(18),
          ),
          border: Border.all(color: c.lavender.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return Row(
                  children: List.generate(3, (i) {
                    final t =
                        ((_controller.value * 3 - i).clamp(0.0, 1.0));
                    final scale = 0.5 + 0.5 * (1 - t);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.5),
                      child: Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: c.lavender,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
            const SizedBox(width: 10),
            Text('Reading your documents…',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _ChatEmptyState extends StatelessWidget {
  const _ChatEmptyState();

  @override
  Widget build(BuildContext context) {
    final c = context.docColors;
    final chat = context.read<ChatProvider>();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 74,
                  height: 74,
                  decoration: BoxDecoration(
                    color: c.lavenderSoft,
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
                SparkleIcon(color: c.lavender, size: 34),
                Positioned(
                  top: 4,
                  right: 8,
                  child: SparkleIcon(color: c.gold, size: 12),
                ),
                Positioned(
                  bottom: 8,
                  left: 6,
                  child: SparkleIcon(color: c.pink, size: 9),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Ask your documents anything',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Answers are grounded in retrieved passages — every claim carries a page citation you can tap.\n\n'
              '"Summarize this document"\n'
              '"What do these papers agree on?"\n'
              '"What is the notice period?"',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.6),
            ),
            const SizedBox(height: 16),
            Material(
              color: c.mintSoft,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => chat.send(
                    'Summarize the most important themes across my documents.'),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.summarize_rounded,
                          size: 16, color: Color(0xFF1E8E7A)),
                      SizedBox(width: 8),
                      Text('Summarize my library',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatInputBar extends StatelessWidget {
  ChatInputBar({super.key});

  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final c = context.docColors;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 4,
                style: Theme.of(context).textTheme.bodyMedium,
                decoration: InputDecoration(
                  hintText: 'Ask about your documents…',
                  filled: true,
                  fillColor: c.surfaceWarm,
                ),
                onSubmitted: (v) {
                  chat.send(v);
                  _controller.clear();
                },
              ),
            ),
            const SizedBox(width: 10),
            Container(
              decoration: BoxDecoration(
                color: chat.sending ? c.outline : c.coral,
                borderRadius: BorderRadius.circular(16),
              ),
              child: IconButton(
                onPressed: chat.sending
                    ? null
                    : () {
                        chat.send(_controller.text);
                        _controller.clear();
                      },
                icon: Icon(Icons.arrow_upward_rounded,
                    color: chat.sending ? c.plum.withValues(alpha: 0.4) : c.onAccent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chat workspace opened from a document (scoped to that doc).
class ChatWorkspaceScreen extends StatelessWidget {
  const ChatWorkspaceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ask AI'),
        leading: const BackButton(),
      ),
      body: const Column(
        children: [
          Expanded(child: MessageList()),
        ],
      ),
      bottomNavigationBar: ChatInputBar(),
    );
  }
}

/// Conversation history view opened from Home recents.
class ConversationViewScreen extends StatelessWidget {
  final String conversationId;
  const ConversationViewScreen({super.key, required this.conversationId});

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!context.mounted) return;
      final chat = context.read<ChatProvider>();
      final target = chat.conversations
          .where((c) => c.id == conversationId)
          .cast<Conversation?>()
          .firstOrNull;
      if (target != null) await chat.openConversation(target);
    });
    return Scaffold(
      body: const MessageList(),
      bottomNavigationBar: ChatInputBar(),
    );
  }
}
