import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../ai/ai_provider.dart';
import '../ai/ai_service_factory.dart';
import '../ai/rag_service.dart';
import '../core/errors/app_exceptions.dart';
import '../data/datasources/chat_datasource.dart';
import '../data/datasources/library_datasource.dart';
import '../data/models/models.dart';
import '../state/settings_provider.dart';

/// Which documents an AI request searches.
class ChatScope {
  final String label;
  final List<String> documentIds;
  final bool entireLibrary;

  const ChatScope._(this.label, this.documentIds, this.entireLibrary);

  const ChatScope.library() : this._('Entire library', const [], true);
  const ChatScope.documents(String title, List<String> ids)
      : this._(title, ids, false);

  static ChatScope single(Document doc) =>
      ChatScope.documents(doc.title, [doc.id]);

  RagScope toRagScope() => entireLibrary
      ? const RagScope.library()
      : RagScope.documents(documentIds);
}

/// State for the AI chat surface: conversation list, active conversation,
/// messages, streaming-ish loading and errors.
class ChatProvider extends ChangeNotifier {
  final ChatDatasource _chatDatasource;
  final LibraryDatasource _libraryDatasource;
  final SettingsProvider _settings;
  final _uuid = const Uuid();

  List<Conversation> _conversations = [];
  Conversation? _activeConversation;
  List<Message> _messages = [];
  bool _sending = false;
  String? _lastError;
  ChatScope _scope = const ChatScope.library();

  ChatProvider({
    required ChatDatasource chatDatasource,
    required LibraryDatasource libraryDatasource,
    required SettingsProvider settings,
  })  : _chatDatasource = chatDatasource,
        _libraryDatasource = libraryDatasource,
        _settings = settings;

  List<Conversation> get conversations => _conversations;
  Conversation? get activeConversation => _activeConversation;
  List<Message> get messages => _messages;
  bool get sending => _sending;
  String? get lastError => _lastError;
  ChatScope get scope => _scope;

  Future<void> refreshConversations() async {
    _conversations = await _chatDatasource.listConversations();
    notifyListeners();
  }

  void setScope(ChatScope scope) {
    _scope = scope;
    notifyListeners();
  }

  Future<void> openConversation(Conversation conversation) async {
    _activeConversation = conversation;
    _messages = await _chatDatasource.listMessages(conversation.id);
    if (conversation.documentIds.isNotEmpty) {
      _scope = ChatScope.documents(conversation.title, conversation.documentIds);
    } else {
      _scope = const ChatScope.library();
    }
    _lastError = null;
    notifyListeners();
  }

  Future<void> startNewConversation() async {
    _activeConversation = null;
    _messages = [];
    _lastError = null;
    notifyListeners();
  }

  /// Sends a question through the RAG pipeline and stores both turns.
  Future<void> send(String text) async {
    final question = text.trim();
    if (question.isEmpty || _sending) return;

    _lastError = null;

    // Create or reuse the conversation.
    var conversation = _activeConversation;
    if (conversation == null) {
      conversation = Conversation(
        id: _uuid.v4(),
        title: question.length > 60 ? '${question.substring(0, 60)}…' : question,
        documentIds: _scope.entireLibrary ? [] : _scope.documentIds,
        collectionIds: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _chatDatasource.createConversation(conversation);
      _activeConversation = conversation;
    }

    // Persist + show the user's message immediately.
    final userMessage = Message(
      id: _uuid.v4(),
      conversationId: conversation.id,
      role: MessageRole.user,
      content: question,
      createdAt: DateTime.now(),
    );
    await _chatDatasource.insertMessage(userMessage);
    _messages = [..._messages, userMessage];
    _sending = true;
    notifyListeners();

    try {
      final config = _settings.aiConfig;
      final factory = AiServiceFactory(_libraryDatasource);
      final rag = factory.createRagService(config);
      if (rag == null) {
        throw AiProviderException(
          'The AI provider is not configured.',
          hint: 'Open Settings → AI Provider to add a key or a local server.',
        );
      }

      // Give the model brief conversation context (last few turns).
      final history = _messages
          .where((m) => m.role == MessageRole.user || m.role == MessageRole.assistant)
          .toList()
          .reversed
          .take(4)
          .toList()
          .reversed
          .map((m) => '${m.role == MessageRole.user ? 'User' : 'Assistant'}: ${m.content}')
          .toList();

      final answer = await rag.answer(
        question: question,
        scope: _scope.toRagScope(),
        config: config,
        task: AiTask.questionAnswering,
        conversationContext: history,
      );

      final assistantMessage = Message(
        id: _uuid.v4(),
        conversationId: conversation.id,
        role: MessageRole.assistant,
        content: answer.answer,
        citations: answer.citations,
        createdAt: DateTime.now(),
      );
      await _chatDatasource.insertMessage(assistantMessage);

      conversation = Conversation(
        id: conversation.id,
        title: conversation.title,
        documentIds: conversation.documentIds,
        collectionIds: conversation.collectionIds,
        createdAt: conversation.createdAt,
        updatedAt: DateTime.now(),
      );
      await _chatDatasource.updateConversation(conversation);

      _messages = [..._messages, assistantMessage];
      _conversations = await _chatDatasource.listConversations();
    } on DocuMindException catch (e) {
      _lastError = e.hint == null ? e.message : '${e.message}\n${e.hint}';
    } catch (e) {
      _lastError =
          'The AI request failed unexpectedly. Your message is saved — try sending it again.';
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  Future<void> deleteConversation(String id) async {
    await _chatDatasource.deleteConversation(id);
    if (_activeConversation?.id == id) {
      _activeConversation = null;
      _messages = [];
    }
    await refreshConversations();
  }

  void clearError() {
    _lastError = null;
    notifyListeners();
  }
}
