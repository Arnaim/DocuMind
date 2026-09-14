import 'package:sqflite/sqflite.dart';

import '../models/models.dart';
import 'app_database.dart';

/// SQLite access for conversations and messages.
class ChatDatasource {
  Future<Database> get _db => AppDatabase.open();

  Future<Conversation> createConversation(Conversation conversation) async {
    final db = await _db;
    await db.insert('conversations', conversation.toRow(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    return conversation;
  }

  Future<Conversation?> getConversation(String id) async {
    final db = await _db;
    final rows = await db
        .query('conversations', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Conversation.fromRow(rows.first);
  }

  Future<List<Conversation>> listConversations({int limit = 50}) async {
    final db = await _db;
    final rows = await db.query('conversations',
        orderBy: 'updated_at DESC', limit: limit);
    return rows.map(Conversation.fromRow).toList();
  }

  Future<void> updateConversation(Conversation conversation) async {
    final db = await _db;
    await db.update('conversations', conversation.toRow(),
        where: 'id = ?', whereArgs: [conversation.id]);
  }

  Future<void> deleteConversation(String id) async {
    final db = await _db;
    await db.delete('conversations', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> insertMessage(Message message) async {
    final db = await _db;
    await db.insert('messages', message.toRow(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Message>> listMessages(String conversationId) async {
    final db = await _db;
    final rows = await db.query('messages',
        where: 'conversation_id = ?',
        whereArgs: [conversationId],
        orderBy: 'created_at ASC');
    return rows.map(Message.fromRow).toList();
  }

  Future<int> messageCount() async {
    final db = await _db;
    final r = await db.rawQuery('SELECT COUNT(*) AS n FROM messages');
    return Sqflite.firstIntValue(r) ?? 0;
  }
}
