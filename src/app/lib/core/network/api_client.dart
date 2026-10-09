import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Renvoie un nouvel access token après un refus du serveur, ou `null` si la
/// session ne peut pas être renouvelée.
typedef AccessTokenRenewer =
    Future<String?> Function(String rejectedAccessToken);

class ApiClient {
  ApiClient({
    required String baseUrl,
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 15),
  }) : _baseUri = Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/'),
       _httpClient = httpClient ?? http.Client(),
       _timeout = timeout;

  final Uri _baseUri;
  final http.Client _httpClient;
  final Duration _timeout;

  /// Appelé quand le serveur répond 401 à une requête authentifiée, par exemple
  /// juste après une approbation dans une classe (le serveur invalide alors les
  /// anciens jetons). La requête est rejouée une fois avec le nouveau jeton.
  AccessTokenRenewer? onAccessTokenRejected;

  Future<Map<String, Object?>> getJson(
    String path, {
    String? accessToken,
  }) async {
    final response = await _send(
      accessToken,
      (headers) => _httpClient.get(_resolve(path), headers: headers),
    );

    return _decodeObjectResponse(response);
  }

  Future<List<Map<String, Object?>>> getJsonList(
    String path, {
    String? accessToken,
  }) async {
    final response = await _send(
      accessToken,
      (headers) => _httpClient.get(_resolve(path), headers: headers),
    );

    return _decodeListResponse(response);
  }

  Future<Map<String, Object?>> postJson(
    String path, {
    required Map<String, Object?> body,
    String? accessToken,
  }) async {
    final response = await _send(
      accessToken,
      (headers) => _httpClient.post(
        _resolve(path),
        headers: headers,
        body: jsonEncode(body),
      ),
    );

    return _decodeObjectResponse(response);
  }

  Future<List<Map<String, Object?>>> postJsonList(
    String path, {
    required Map<String, Object?> body,
    String? accessToken,
  }) async {
    final response = await _send(
      accessToken,
      (headers) => _httpClient.post(
        _resolve(path),
        headers: headers,
        body: jsonEncode(body),
      ),
    );

    return _decodeListResponse(response);
  }

  Future<Map<String, Object?>> putJson(
    String path, {
    required Map<String, Object?> body,
    String? accessToken,
  }) async {
    final response = await _send(
      accessToken,
      (headers) => _httpClient.put(
        _resolve(path),
        headers: headers,
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
      accessToken,
      (headers) => _httpClient.post(
        _resolve(path),
        headers: headers,
        body: jsonEncode(body),
      ),
    );

    _ensureSuccess(response);
  }

  Future<void> putNoContent(
    String path, {
    required Map<String, Object?> body,
    String? accessToken,
  }) async {
    final response = await _send(
      accessToken,
      (headers) => _httpClient.put(
        _resolve(path),
        headers: headers,
        body: jsonEncode(body),
      ),
    );

    _ensureSuccess(response);
  }

  /// Télécharge un fichier (contenu brut) avec le jeton de l'utilisateur.
  Future<Uint8List> getBytes(String path, {String? accessToken}) async {
    final response = await _send(
      accessToken,
      (headers) => _httpClient.get(_resolve(path), headers: headers),
      timeout: const Duration(seconds: 60),
    );

    _ensureSuccess(response);
    return response.bodyBytes;
  }

  /// Envoie un fichier en multipart/form-data (champ [fileField]).
  Future<Map<String, Object?>> postFile(
    String path, {
    required String fileName,
    required List<int> bytes,
    String fileField = 'file',
    Map<String, String> fields = const {},
    String? accessToken,
  }) async {
    final response = await _send(accessToken, (headers) async {
      final request = http.MultipartRequest('POST', _resolve(path))
        ..headers.addAll(Map.of(headers)..remove('Content-Type'))
        ..fields.addAll(fields)
        ..files.add(
          http.MultipartFile.fromBytes(fileField, bytes, filename: fileName),
        );
      return http.Response.fromStream(await _httpClient.send(request));
    }, timeout: const Duration(seconds: 90));

    return _decodeObjectResponse(response);
  }

  Future<void> deleteNoContent(String path, {String? accessToken}) async {
    final response = await _send(
      accessToken,
      (headers) => _httpClient.delete(_resolve(path), headers: headers),
    );

    _ensureSuccess(response);
  }

  Future<http.Response> _send(
    String? accessToken,
    Future<http.Response> Function(Map<String, String> headers) request, {
    Duration? timeout,
  }) async {
    final response = await _sendOnce(
      () => request(_headers(accessToken)),
      timeout: timeout,
    );

    final renewer = onAccessTokenRejected;
    if (response.statusCode != 401 || accessToken == null || renewer == null) {
      return response;
    }

    final renewedToken = await renewer(accessToken);
    if (renewedToken == null || renewedToken == accessToken) return response;

    return _sendOnce(() => request(_headers(renewedToken)), timeout: timeout);
  }

  Future<http.Response> _sendOnce(
    Future<http.Response> Function() request, {
    Duration? timeout,
  }) async {
    try {
      return await request().timeout(timeout ?? _timeout);
    } on TimeoutException {
      throw const ApiException(
        statusCode: 0,
        message: 'Le serveur ne répond pas. Réessaie dans un instant.',
      );
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

  void _ensureSuccess(http.Response response) {
    if (response.statusCode == 413) {
      // Refus du proxy avant même l'API : la réponse n'est pas du JSON.
      throw const ApiException(
        statusCode: 413,
        message: 'Fichier trop lourd pour le serveur.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        statusCode: response.statusCode,
        message: _readProblemMessage(response.body) ?? 'Erreur API.',
      );
    }
  }

  Map<String, Object?> _decodeObjectResponse(http.Response response) {
    _ensureSuccess(response);

    final decoded = _decodeBody(response.body);
    if (decoded is Map<String, Object?>) return decoded;

    throw const ApiException(statusCode: 0, message: 'Réponse API invalide.');
  }

  List<Map<String, Object?>> _decodeListResponse(http.Response response) {
    _ensureSuccess(response);

    final decoded = _decodeBody(response.body);
    if (decoded is List<Object?>) {
      return decoded.whereType<Map<String, Object?>>().toList(growable: false);
    }

    throw const ApiException(statusCode: 0, message: 'Réponse API invalide.');
  }

  Object? _decodeBody(String body) {
    try {
      return jsonDecode(body);
    } on FormatException {
      throw const ApiException(statusCode: 0, message: 'Réponse API invalide.');
    }
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

        // Le titre dit ce qui ne va pas, le détail comment s'en sortir.
        final title = decoded['title'] as String?;
        final detail = decoded['detail'] as String?;
        if (title != null && detail != null) return '$title $detail';
        return detail ?? title;
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
