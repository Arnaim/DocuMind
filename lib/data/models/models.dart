import 'dart:convert';

import '../../core/constants/doc_formats.dart';

/// Lifecycle of a document inside the processing pipeline.
enum ProcessingStatus {
  imported,
  processing,
  indexed,
  ready,
  failed;

  String get label => switch (this) {
        ProcessingStatus.imported => 'Imported',
        ProcessingStatus.processing => 'Processing',
        ProcessingStatus.indexed => 'Indexed',
        ProcessingStatus.ready => 'Ready',
        ProcessingStatus.failed => 'Failed',
      };
}

/// A document in the user's library. The original file always stays on disk;
/// the database only holds metadata and references.
class Document {
  final String id;
  final String title;
  final String fileName;
  final String filePath;
  final DocFormat format;
  final int fileSizeBytes;
  final DateTime importedAt;
  final DateTime modifiedAt;
  final DateTime? lastOpenedAt;
  final bool isFavorite;
  final int pageCount;
  final int charCount;
  final int wordCount;
  final ProcessingStatus status;
  final String? errorMessage;
  final bool hasEmbeddings;

  const Document({
    required this.id,
    required this.title,
    required this.fileName,
    required this.filePath,
    required this.format,
    required this.fileSizeBytes,
    required this.importedAt,
    required this.modifiedAt,
    this.lastOpenedAt,
    this.isFavorite = false,
    this.pageCount = 1,
    this.charCount = 0,
    this.wordCount = 0,
    this.status = ProcessingStatus.imported,
    this.errorMessage,
    this.hasEmbeddings = false,
  });

  Document copyWith({
    String? title,
    String? filePath,
    bool? isFavorite,
    int? pageCount,
    int? charCount,
    int? wordCount,
    ProcessingStatus? status,
    String? errorMessage,
    DateTime? lastOpenedAt,
    bool? hasEmbeddings,
  }) =>
      Document(
        id: id,
        title: title ?? this.title,
        fileName: fileName,
        filePath: filePath ?? this.filePath,
        format: format,
        fileSizeBytes: fileSizeBytes,
        importedAt: importedAt,
        modifiedAt: modifiedAt,
        lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
        isFavorite: isFavorite ?? this.isFavorite,
        pageCount: pageCount ?? this.pageCount,
        charCount: charCount ?? this.charCount,
        wordCount: wordCount ?? this.wordCount,
        status: status ?? this.status,
        errorMessage: errorMessage ?? this.errorMessage,
        hasEmbeddings: hasEmbeddings ?? this.hasEmbeddings,
      );

  Map<String, Object?> toRow() => {
        'id': id,
        'title': title,
        'file_name': fileName,
        'file_path': filePath,
        'format': format.name,
        'file_size': fileSizeBytes,
        'imported_at': importedAt.toIso8601String(),
        'modified_at': modifiedAt.toIso8601String(),
        'last_opened_at': lastOpenedAt?.toIso8601String(),
        'is_favorite': isFavorite ? 1 : 0,
        'page_count': pageCount,
        'char_count': charCount,
        'word_count': wordCount,
        'status': status.name,
        'error_message': errorMessage,
        'has_embeddings': hasEmbeddings ? 1 : 0,
      };

  static Document fromRow(Map<String, Object?> row) => Document(
        id: row['id'] as String,
        title: row['title'] as String,
        fileName: row['file_name'] as String,
        filePath: row['file_path'] as String,
        format: DocFormat.values.firstWhere(
          (f) => f.name == row['format'],
          orElse: () => DocFormat.unknown,
        ),
        fileSizeBytes: row['file_size'] as int,
        importedAt: DateTime.parse(row['imported_at'] as String),
        modifiedAt: DateTime.parse(row['modified_at'] as String),
        lastOpenedAt: row['last_opened_at'] == null
            ? null
            : DateTime.parse(row['last_opened_at'] as String),
        isFavorite: (row['is_favorite'] as int) == 1,
        pageCount: row['page_count'] as int,
        charCount: row['char_count'] as int,
        wordCount: row['word_count'] as int,
        status: ProcessingStatus.values.firstWhere(
          (s) => s.name == row['status'],
          orElse: () => ProcessingStatus.imported,
        ),
        errorMessage: row['error_message'] as String?,
        hasEmbeddings: (row['has_embeddings'] as int?) == 1,
      );

  static int estimateWords(int charCount) => (charCount / 5.5).round();
}

/// A retrieval unit produced by the pipeline: text plus citation metadata.
class Chunk {
  final String id;
  final String documentId;
  final String text;
  final int pageNumber;
  final String? section;
  final int position;

  const Chunk({
    required this.id,
    required this.documentId,
    required this.text,
    required this.pageNumber,
    this.section,
    required this.position,
  });

  Map<String, Object?> toRow() => {
        'id': id,
        'document_id': documentId,
        'text': text,
        'page_number': pageNumber,
        'section': section,
        'position': position,
      };

  static Chunk fromRow(Map<String, Object?> row) => Chunk(
        id: row['id'] as String,
        documentId: row['document_id'] as String,
        text: row['text'] as String,
        pageNumber: row['page_number'] as int,
        section: row['section'] as String?,
        position: row['position'] as int,
      );
}

/// A user-defined grouping of documents ("University", "Work", …).
class Collection {
  final String id;
  final String name;
  final DateTime createdAt;
  final String? colorHex;

  const Collection({
    required this.id,
    required this.name,
    required this.createdAt,
    this.colorHex,
  });

  Map<String, Object?> toRow() => {
        'id': id,
        'name': name,
        'created_at': createdAt.toIso8601String(),
        'color': colorHex,
      };

  static Collection fromRow(Map<String, Object?> row) => Collection(
        id: row['id'] as String,
        name: row['name'] as String,
        createdAt: DateTime.parse(row['created_at'] as String),
        colorHex: row['color'] as String?,
      );
}

/// Role of a chat message within a conversation.
enum MessageRole { user, assistant }

/// One turn of an AI conversation.
class Message {
  final String id;
  final String conversationId;
  final MessageRole role;
  final String content;
  final List<Citation> citations;
  final DateTime createdAt;

  const Message({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    this.citations = const [],
    required this.createdAt,
  });

  Map<String, Object?> toRow() => {
        'id': id,
        'conversation_id': conversationId,
        'role': role.name,
        'content': content,
        'citations_json': jsonEncode(citations.map((c) => c.toJson()).toList()),
        'created_at': createdAt.toIso8601String(),
      };

  static Message fromRow(Map<String, Object?> row) => Message(
        id: row['id'] as String,
        conversationId: row['conversation_id'] as String,
        role: MessageRole.values.firstWhere(
          (r) => r.name == row['role'],
          orElse: () => MessageRole.assistant,
        ),
        content: row['content'] as String,
        citations: Citation.decodeList(row['citations_json'] as String?),
        createdAt: DateTime.parse(row['created_at'] as String),
      );
}

/// A conversation with the AI about a scope of documents.
class Conversation {
  final String id;
  final String title;
  final List<String> documentIds;
  final List<String> collectionIds;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Conversation({
    required this.id,
    required this.title,
    this.documentIds = const [],
    this.collectionIds = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, Object?> toRow() => {
        'id': id,
        'title': title,
        'document_ids_json': documentIds.join(','),
        'collection_ids_json': collectionIds.join(','),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  static Conversation fromRow(Map<String, Object?> row) => Conversation(
        id: row['id'] as String,
        title: row['title'] as String,
        documentIds: (row['document_ids_json'] as String? ?? '')
            .split(',')
            .where((s) => s.isNotEmpty)
            .toList(),
        collectionIds: (row['collection_ids_json'] as String? ?? '')
            .split(',')
            .where((s) => s.isNotEmpty)
            .toList(),
        createdAt: DateTime.parse(row['created_at'] as String),
        updatedAt: DateTime.parse(row['updated_at'] as String),
      );
}

/// Reference from an AI answer back to the exact place in a document the
/// statement came from. Tapping it opens the document near that location.
class Citation {
  final String chunkId;
  final String documentId;
  final String documentTitle;
  final int page;
  final String? section;
  final String snippet;

  const Citation({
    required this.chunkId,
    required this.documentId,
    required this.documentTitle,
    required this.page,
    this.section,
    required this.snippet,
  });

  Map<String, Object?> toJson() => {
        'chunkId': chunkId,
        'documentId': documentId,
        'documentTitle': documentTitle,
        'page': page,
        if (section != null) 'section': section,
        'snippet': snippet,
      };

  static Citation fromJson(Map<String, Object?> json) => Citation(
        chunkId: json['chunkId'] as String,
        documentId: json['documentId'] as String,
        documentTitle: json['documentTitle'] as String? ?? 'Document',
        page: json['page'] as int? ?? 1,
        section: json['section'] as String?,
        snippet: json['snippet'] as String? ?? '',
      );

  static String encodeList(List<Citation> list) =>
      jsonEncode(list.map((c) => c.toJson()).toList());

  static List<Citation> decodeList(String? encoded) {
    if (encoded == null || encoded.isEmpty) return const [];
    try {
      final list = jsonDecode(encoded) as List;
      return list
          .map((e) => Citation.fromJson((e as Map).cast<String, Object?>()))
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
