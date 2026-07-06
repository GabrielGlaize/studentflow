import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiClient {
  ApiClient({required String baseUrl, http.Client? httpClient})
    : _baseUri = Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/'),
      _httpClient = httpClient ?? http.Client();

  final Uri _baseUri;
  final http.Client _httpClient;

  Future<Map<String, Object?>> getJson(
    String path, {
    String? accessToken,
  }) async {
    final response = await _send(
      () => _httpClient.get(_resolve(path), headers: _headers(accessToken)),
    );

    return _decodeObjectResponse(response);
  }

  Future<List<Map<String, Object?>>> getJsonList(
    String path, {
    String? accessToken,
  }) async {
    final response = await _send(
      () => _httpClient.get(_resolve(path), headers: _headers(accessToken)),
    );

    return _decodeListResponse(response);
  }

  Future<Map<String, Object?>> postJson(
    String path, {
    required Map<String, Object?> body,
    String? accessToken,
  }) async {
    final response = await _send(
      () => _httpClient.post(
        _resolve(path),
        headers: _headers(accessToken),
        body: jsonEncode(body),
      ),
    );

    return _decodeObjectResponse(response);
  }

  Future<Map<String, Object?>> putJson(
    String path, {
    required Map<String, Object?> body,
    String? accessToken,
  }) async {
    final response = await _send(
      () => _httpClient.put(
        _resolve(path),
        headers: _headers(accessToken),
        body: jsonEncode(body),
      ),
    );

    return _decodeObjectResponse(response);
  }

  Future<void> postNoContent(
    String path, {
    required Map<String, Object?> body,
    String? accessToken,
  }) async {
    final response = await _send(
      () => _httpClient.post(
        _resolve(path),
        headers: _headers(accessToken),
        body: jsonEncode(body),
      ),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        statusCode: response.statusCode,
        message: _readProblemMessage(response.body) ?? 'Erreur API.',
      );
    }
  }

  Future<void> deleteNoContent(String path, {String? accessToken}) async {
    final response = await _send(
      () => _httpClient.delete(_resolve(path), headers: _headers(accessToken)),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        statusCode: response.statusCode,
        message: _readProblemMessage(response.body) ?? 'Erreur API.',
      );
    }
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request();
    } on http.ClientException {
      throw const ApiException(
        statusCode: 0,
        message: 'Impossible de joindre le serveur.',
      );
    } on FormatException {
      throw const ApiException(statusCode: 0, message: 'Adresse API invalide.');
    }
  }

  Uri _resolve(String path) {
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    return _baseUri.resolve(normalizedPath);
  }

  Map<String, String> _headers(String? accessToken) {
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (accessToken != null) 'Authorization': 'Bearer $accessToken',
    };
  }

  Map<String, Object?> _decodeObjectResponse(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        statusCode: response.statusCode,
        message: _readProblemMessage(response.body) ?? 'Erreur API.',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, Object?>) return decoded;

    throw const ApiException(statusCode: 0, message: 'Réponse API invalide.');
  }

  List<Map<String, Object?>> _decodeListResponse(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        statusCode: response.statusCode,
        message: _readProblemMessage(response.body) ?? 'Erreur API.',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is List<Object?>) {
      return decoded.whereType<Map<String, Object?>>().toList(growable: false);
    }

    throw const ApiException(statusCode: 0, message: 'Réponse API invalide.');
  }

  String? _readProblemMessage(String body) {
    if (body.isEmpty) return null;

    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, Object?>) {
        final errors = decoded['errors'];
        if (errors is Map<String, Object?>) {
          final messages = <_ProblemMessage>[];
          for (final entry in errors.entries) {
            final values = entry.value;
            if (values is List<Object?>) {
              for (final value in values.whereType<String>()) {
                messages.add(_ProblemMessage(entry.key, value));
              }
            }
          }
          if (messages.isNotEmpty) {
            _ProblemMessage? usefulMessage;
            for (final message in messages) {
              final lowerText = message.text.toLowerCase();
              if (message.field.toLowerCase() != 'request' &&
                  !lowerText.contains('request field is required')) {
                usefulMessage = message;
                break;
              }
            }

            return usefulMessage?.text ?? messages.first.text;
          }
        }

        return decoded['detail'] as String? ?? decoded['title'] as String?;
      }
    } on FormatException {
      return null;
    }

    return null;
  }
}

class ApiException implements Exception {
  const ApiException({required this.statusCode, required this.message});

  final int statusCode;
  final String message;

  @override
  String toString() => message;
}

class _ProblemMessage {
  const _ProblemMessage(this.field, this.text);

  final String field;
  final String text;
}
