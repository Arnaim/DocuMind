import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exceptions.dart';
import '../ai_provider.dart';

/// Google Gemini provider (generativelanguage.googleapis.com).
///
/// Free-tier friendly. The API key is supplied by the user at runtime and kept
/// in local settings — it is never compiled into the app binary (see README
/// security notes).
class GeminiProvider implements AiProvider {
  static const _endpoint = 'https://generativelanguage.googleapis.com/v1beta/models';

  final http.Client _client;
  GeminiProvider({http.Client? client}) : _client = client ?? http.Client();

  @override
  String get id => 'gemini';
  @override
  String get displayName => 'Google Gemini';
  @override
  AiProviderKind get kind => AiProviderKind.cloud;

  @override
  List<String> get availableModels => const [
        'gemini-2.0-flash',
        'gemini-2.0-flash-lite',
        'gemini-1.5-flash',
        'gemini-1.5-flash-8b',
        'gemini-1.5-pro',
      ];

  @override
  bool get isConfigured => true; // key checked per-call via statusLabel

  @override
  String statusLabel(AiConfig config) =>
      (config.apiKey == null || config.apiKey!.trim().isEmpty)
          ? 'API key required'
          : 'Ready';

  @override
  Future<AiResponse> complete(AiRequest request, AiConfig config) async {
    final key = config.apiKey?.trim();
    if (key == null || key.isEmpty) {
      throw AiProviderException(
        'No Gemini API key configured.',
        hint: 'Open Settings → AI Provider and add a free key from Google AI Studio.',
      );
    }

    final url =
        '$_endpoint/${config.model}:generateContent?key=$key&alt=sse';
    final body = jsonEncode({
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': '${request.systemPrompt}\n\n---\n\n${request.userPrompt}'}
          ]
        }
      ],
      'generationConfig': {
        'temperature': request.temperature,
        'maxOutputTokens': request.maxOutputTokens,
      },
      'safetySettings': _blockNone(),
    });

    try {
      final response = await _client
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(AppConstants.aiRequestTimeout);

      if (response.statusCode != 200) {
        throw httpErrorToAiException(response.statusCode, 'Gemini',
            body: response.body);
      }

      // Parse SSE stream (alt=sse) — robust against partial JSON issues.
      final text = _parseSse(response.body);
      if (text == null || text.trim().isEmpty) {
        throw AiProviderException(
          'Gemini returned an empty response.',
          hint: 'The prompt may have been filtered by safety settings. Try rephrasing.',
        );
      }
      return AiResponse(text: text.trim());
    } on TimeoutException {
      throw AiProviderException(
        'Gemini did not respond in time.',
        hint: 'Try a shorter question or reduce the number of documents in scope.',
      );
    } on http.ClientException catch (e) {
      throw mapAiError(e, providerName: 'Gemini');
    }
  }

  @override
  Future<List<double>?> embed(String text, AiConfig config) async {
    final key = config.apiKey?.trim();
    if (key == null || key.isEmpty) return null;

    final url =
        '$_endpoint/${config.model.contains('embedding') ? config.model : 'gemini-embedding-001'}:embedContent?key=$key';
    try {
      final response = await _client
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'model':
                  'models/${config.model.contains('embedding') ? config.model : 'gemini-embedding-001'}',
              'content': {
                'parts': [
                  {'text': text.length > 8000 ? text.substring(0, 8000) : text}
                ]
              },
            }),
          )
          .timeout(AppConstants.aiRequestTimeout);

      if (response.statusCode != 200) return null;
      final json = jsonDecode(response.body) as Map<String, Object?>;
      final values = ((json['embedding'] as Map?)?['values'] as List?) ?? const [];
      return values.map((v) => (v as num).toDouble()).toList();
    } catch (_) {
      return null;
    }
  }

  /// Extracts the concatenated text parts from an SSE body.
  String? _parseSse(String body) {
    final buffer = StringBuffer();
    var found = false;
    for (final line in body.split('\n')) {
      if (!line.startsWith('data:')) continue;
      final payload = line.substring(5).trim();
      if (payload.isEmpty || payload == '[DONE]') continue;
      try {
        final json = jsonDecode(payload) as Map<String, Object?>;
        final candidates = json['candidates'] as List?;
        if (candidates == null || candidates.isEmpty) continue;
        final content =
            ((candidates.first as Map)['content'] as Map?)?['parts'] as List?;
        if (content == null) continue;
        for (final part in content) {
          final t = (part as Map)['text'] as String?;
          if (t != null) {
            buffer.write(t);
            found = true;
          }
        }
      } catch (_) {
        continue;
      }
    }
    return found ? buffer.toString() : null;
  }

  List<Map<String, Object>> _blockNone() => [
        {
          'category': 'HARM_CATEGORY_HARASSMENT',
          'threshold': 'BLOCK_ONLY_HIGH'
        },
        {
          'category': 'HARM_CATEGORY_HATE_SPEECH',
          'threshold': 'BLOCK_ONLY_HIGH'
        },
        {
          'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
          'threshold': 'BLOCK_ONLY_HIGH'
        },
        {
          'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
          'threshold': 'BLOCK_ONLY_HIGH'
        },
      ];
}
