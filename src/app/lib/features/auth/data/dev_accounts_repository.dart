import 'package:studyflow_app/core/network/api_client.dart';

/// Un compte du seed de développement et la situation qu'il permet de tester.
class DevAccount {
  const DevAccount({
    required this.email,
    required this.password,
    required this.firstName,
    required this.lastName,
    required this.situation,
    required this.details,
    this.isDelegate = false,
    this.hasClass = true,
    this.firstLaunch = false,
  });

  final String email;
  final String password;
  final String firstName;
  final String lastName;
  final String situation;
  final String details;
  final bool isDelegate;
  final bool hasClass;

  /// L'app ouvre la présentation après la connexion, comme pour un compte neuf.
  final bool firstLaunch;

  String get displayName => '$firstName $lastName'.trim();

  factory DevAccount.fromJson(Map<String, Object?> json) {
    return DevAccount(
      email: json['email'] as String,
      password: json['password'] as String,
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String,
      situation: json['situation'] as String,
      details: json['details'] as String? ?? '',
      isDelegate: json['isDelegate'] as bool? ?? false,
      hasClass: json['hasClass'] as bool? ?? true,
      firstLaunch: json['firstLaunch'] as bool? ?? false,
    );
  }
}

/// Comptes du seed, servis par l'API de dev (`GET /api/v1/dev/accounts`).
/// La route n'existe pas en production.
abstract interface class DevAccountsRepository {
  Future<List<DevAccount>> list();
}

class HttpDevAccountsRepository implements DevAccountsRepository {
  const HttpDevAccountsRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<List<DevAccount>> list() async {
    final items = await _apiClient.getJsonList('/api/v1/dev/accounts');
    return items.map(DevAccount.fromJson).toList(growable: false);
  }
}
