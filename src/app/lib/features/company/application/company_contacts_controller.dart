import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CompanyContact {
  const CompanyContact({
    required this.id,
    required this.name,
    required this.role,
    this.email,
    this.phone,
  });

  final String id;
  final String name;
  final String role;
  final String? email;
  final String? phone;

  factory CompanyContact.fromJson(Map<String, Object?> json) {
    return CompanyContact(
      id: json['id'] as String,
      name: json['name'] as String,
      role: json['role'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'name': name,
      'role': role,
      'email': email,
      'phone': phone,
    };
  }
}

class CompanyContactsController extends ChangeNotifier {
  CompanyContactsController({required CompanyContactsStorage storage})
    : _storage = storage;

  final CompanyContactsStorage _storage;
  final List<CompanyContact> _contacts = [];

  List<CompanyContact> get contacts => List.unmodifiable(_contacts);

  Future<void> restore() async {
    final savedContacts = await _storage.read();
    _contacts
      ..clear()
      ..addAll(savedContacts);
    notifyListeners();
  }

  void addContact({
    required String name,
    required String role,
    String? email,
    String? phone,
  }) {
    final contact = CompanyContact(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name.trim(),
      role: role.trim(),
      email: _cleanOptional(email),
      phone: _cleanOptional(phone),
    );

    _contacts.insert(0, contact);
    _save();
    notifyListeners();
  }

  void deleteContact(String contactId) {
    _contacts.removeWhere((contact) => contact.id == contactId);
    _save();
    notifyListeners();
  }

  void _save() {
    unawaited(_storage.save(_contacts));
  }

  String? _cleanOptional(String? value) {
    final cleaned = value?.trim();
    if (cleaned == null || cleaned.isEmpty) return null;
    return cleaned;
  }
}

abstract interface class CompanyContactsStorage {
  Future<List<CompanyContact>> read();

  Future<void> save(List<CompanyContact> contacts);
}

class SecureCompanyContactsStorage implements CompanyContactsStorage {
  SecureCompanyContactsStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _contactsKey = 'studyflow.company.contacts';

  final FlutterSecureStorage _storage;

  @override
  Future<List<CompanyContact>> read() async {
    final rawContacts = await _storage.read(key: _contactsKey);
    if (rawContacts == null) return const [];

    final decoded = jsonDecode(rawContacts);
    if (decoded is! List<Object?>) return const [];

    return decoded
        .whereType<Map<String, Object?>>()
        .map(CompanyContact.fromJson)
        .toList(growable: false);
  }

  @override
  Future<void> save(List<CompanyContact> contacts) {
    final jsonContacts = contacts.map((contact) => contact.toJson()).toList();
    return _storage.write(key: _contactsKey, value: jsonEncode(jsonContacts));
  }
}

class MemoryCompanyContactsStorage implements CompanyContactsStorage {
  List<CompanyContact> _contacts = const [];

  @override
  Future<List<CompanyContact>> read() async => _contacts;

  @override
  Future<void> save(List<CompanyContact> contacts) async {
    _contacts = List.unmodifiable(contacts);
  }
}
