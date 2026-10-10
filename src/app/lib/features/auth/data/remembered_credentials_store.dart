import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// « Mémoriser mes identifiants » : e-mail et mot de passe gardés dans le
/// trousseau sécurisé du téléphone (Keychain / Keystore), jamais en clair.
class RememberedCredentials {
  const RememberedCredentials({required this.email, required this.password});

  final String email;
  final String password;
}

class RememberedCredentialsStore {
  RememberedCredentialsStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'studyflow.remembered-credentials';

  final FlutterSecureStorage _storage;

  Future<RememberedCredentials?> read() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null) return null;
      final json = jsonDecode(raw);
      if (json is! Map<String, Object?>) return null;
      final email = json['email'];
      final password = json['password'];
      if (email is! String || password is! String) return null;
      return RememberedCredentials(email: email, password: password);
    } on Exception {
      return null;
    }
  }

  Future<void> save(RememberedCredentials credentials) {
    return _storage.write(
      key: _key,
      value: jsonEncode({
        'email': credentials.email,
        'password': credentials.password,
      }),
    );
  }

  Future<void> clear() => _storage.delete(key: _key);
}
