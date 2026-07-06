import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:studyflow_app/features/auth/domain/auth_models.dart';

abstract interface class SessionStorage {
  Future<AuthSession?> read();

  Future<void> save(AuthSession session);

  Future<void> clear();
}

class SecureSessionStorage implements SessionStorage {
  SecureSessionStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _sessionKey = 'studyflow.session';

  final FlutterSecureStorage _storage;

  @override
  Future<AuthSession?> read() async {
    final rawSession = await _storage.read(key: _sessionKey);
    if (rawSession == null) return null;

    final decoded = jsonDecode(rawSession);
    if (decoded is! Map<String, Object?>) return null;

    return AuthSession.fromJson(decoded);
  }

  @override
  Future<void> save(AuthSession session) {
    return _storage.write(
      key: _sessionKey,
      value: jsonEncode(session.toJson()),
    );
  }

  @override
  Future<void> clear() {
    return _storage.delete(key: _sessionKey);
  }
}

class MemorySessionStorage implements SessionStorage {
  AuthSession? _session;

  @override
  Future<AuthSession?> read() async => _session;

  @override
  Future<void> save(AuthSession session) async {
    _session = session;
  }

  @override
  Future<void> clear() async {
    _session = null;
  }
}
