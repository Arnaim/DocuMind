/// An exception carrying a user-actionable message (never "something went
/// wrong"). Throwers must provide text that tells the user what happened and,
/// where possible, what they can do about it.
class DocuMindException implements Exception {
  final String message;
  final String? hint;
  final Object? cause;

  DocuMindException(this.message, {this.hint, this.cause});

  @override
  String toString() => hint == null ? message : '$message\n$hint';
}

/// Thrown when a file cannot be parsed or its text cannot be extracted.
class ParseException extends DocuMindException {
  ParseException(super.message, {super.hint, super.cause});
}

/// Thrown when a document needs a password or is structurally unreadable.
class ProtectedDocumentException extends ParseException {
  ProtectedDocumentException(
    String message,
  ) : super(
          message,
          hint:
              'Encrypted or password-protected files are not supported yet. Remove the password and re-import.',
        );
}

/// Thrown when text extraction succeeds but produces nothing usable.
class EmptyDocumentException extends ParseException {
  EmptyDocumentException({String? message, String? hint})
      : super(
          message ??
              'This document does not contain selectable text — it may consist of scanned images.',
          hint: hint ??
              'OCR for scanned documents and images is planned. Try a text-based export instead.',
        );
}

/// Thrown when an AI provider call fails for a known, explainable reason.
class AiProviderException extends DocuMindException {
  final int? statusCode;

  AiProviderException(super.message, {this.statusCode, super.hint, super.cause});
}

/// Thrown when the device has no connectivity and a cloud call was attempted.
class OfflineException extends DocuMindException {
  OfflineException()
      : super(
          'You are offline.',
          hint:
              'Your documents, local search and previous conversations remain fully available. AI responses need an internet connection.',
        );
}
