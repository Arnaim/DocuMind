import 'package:flutter/foundation.dart';

import '../data/datasources/chat_datasource.dart';
import '../data/datasources/library_datasource.dart';
import '../data/models/models.dart';

/// Dashboard state for the Home screen.
class HomeProvider extends ChangeNotifier {
  final LibraryDatasource _library;
  final ChatDatasource _chat;

  int _documentCount = 0;
  int _collectionCount = 0;
  int _messageCount = 0;
  List<Document> _recent = [];
  List<Document> _favorites = [];
  List<Conversation> _recentConversations = [];
  bool _loading = false;

  HomeProvider({required LibraryDatasource library, required ChatDatasource chat})
      : _library = library,
        _chat = chat;

  int get documentCount => _documentCount;
  int get collectionCount => _collectionCount;
  int get messageCount => _messageCount;
  List<Document> get recent => _recent;
  List<Document> get favorites => _favorites;
  List<Conversation> get recentConversations => _recentConversations;
  bool get loading => _loading;

  Future<void> refresh() async {
    _loading = true;
    notifyListeners();
    try {
      final collections = await _library.listCollections();
      _documentCount = await _library.documentCount();
      _collectionCount = collections.length;
      _messageCount = await _chat.messageCount();
      _recent = await _library.recentDocuments(4);
      _favorites = await _library.favoriteDocuments();
      _recentConversations = await _chat.listConversations(limit: 3);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
