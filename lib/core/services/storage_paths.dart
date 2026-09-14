import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../errors/app_exceptions.dart';

/// Resolves the on-device folders DocuMind writes to. Documents are stored as
/// original files under app-support/documents/<uuid>/<name>; only metadata and
/// references live in SQLite (see architecture docs).
class StoragePaths {
  static Directory? _documentsDir;
  static Directory? _cacheDir;

  static Future<Directory> documentsDir() async {
    if (_documentsDir != null) return _documentsDir!;
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/documents');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    _documentsDir = dir;
    return dir;
  }

  static Future<Directory> cacheDir() async {
    if (_cacheDir != null) return _cacheDir!;
    final base = await getTemporaryDirectory();
    final dir = Directory('${base.path}/documind');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    _cacheDir = dir;
    return dir;
  }

  /// Creates a per-document folder and returns it.
  static Future<Directory> createDocumentFolder(String documentId) async {
    final root = await documentsDir();
    final dir = Directory('${root.path}/$documentId');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  /// Moves [sourceFile] into the per-document folder, preserving the original
  /// file name. Returns the final path.
  static Future<String> storeFile(String documentId, File sourceFile) async {
    final folder = await createDocumentFolder(documentId);
    final safeName = sourceFile.uri.pathSegments.last.replaceAll(RegExp(r'[/\\]'), '_');
    final target = '${folder.path}/$safeName';
    try {
      return await sourceFile.copy(target).then((f) => f.path);
    } on FileSystemException catch (e) {
      throw DocuMindException(
        'Could not copy the document into the library.',
        hint: 'Check free storage space and try again.',
        cause: e,
      );
    }
  }

  static Future<void> deleteDocumentFolder(String documentId) async {
    final root = await documentsDir();
    final dir = Directory('${root.path}/$documentId');
    if (dir.existsSync()) await dir.delete(recursive: true);
  }
}
