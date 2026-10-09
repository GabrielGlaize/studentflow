import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CompanyDocument {
  const CompanyDocument({
    required this.id,
    required this.title,
    required this.kind,
    this.scope = 'company',
    this.link,
    this.note,
    this.fileName,
    this.filePath,
    this.fileSizeBytes,
  });

  final String id;
  final String title;
  final String kind;
  final String scope;
  final String? link;
  final String? note;
  final String? fileName;
  final String? filePath;
  final int? fileSizeBytes;

  bool get hasLocalFile => filePath != null && filePath!.trim().isNotEmpty;

  factory CompanyDocument.fromJson(Map<String, Object?> json) {
    return CompanyDocument(
      id: json['id'] as String,
      title: json['title'] as String,
      kind: json['kind'] as String,
      scope: json['scope'] as String? ?? 'company',
      link: json['link'] as String?,
      note: json['note'] as String?,
      fileName: json['fileName'] as String?,
      filePath: json['filePath'] as String?,
      fileSizeBytes: json['fileSizeBytes'] as int?,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'title': title,
      'kind': kind,
      'scope': scope,
      'link': link,
      'note': note,
      'fileName': fileName,
      'filePath': filePath,
      'fileSizeBytes': fileSizeBytes,
    };
  }
}

class CompanyDocumentsController extends ChangeNotifier {
  CompanyDocumentsController({required CompanyDocumentsStorage storage})
    : _storage = storage;

  final CompanyDocumentsStorage _storage;
  static const int maxDocuments = 80;
  static const int maxCustomKinds = 20;

  /// Types proposés d'office pour un document d'alternance.
  static const baseKinds = [
    'Contrat',
    'Convention',
    'Avenant',
    'Fiche de paie',
    'Attestation',
    'Évaluation',
    'Mutuelle',
    'Note de frais',
  ];

  final List<CompanyDocument> _documents = [];
  final List<String> _customKinds = [];

  List<CompanyDocument> get documents => List.unmodifiable(_documents);

  /// Types personnalisés, créés par l'élève et proposés à nouveau ensuite.
  List<String> get customKinds => List.unmodifiable(_customKinds);

  /// Tous les types à proposer : ceux de base puis les personnalisés.
  List<String> get kinds => [...baseKinds, ..._customKinds];

  Future<void> restore() async {
    final savedDocuments = await _storage.read();
    final savedKinds = await _storage.readKinds();
    _documents
      ..clear()
      ..addAll(savedDocuments);
    _customKinds
      ..clear()
      ..addAll(savedKinds);
    // Documents enregistrés avant les types de base : leur type libre devient
    // un type personnalisé, pour rester proposé.
    for (final document in savedDocuments) {
      if (document.scope == 'company') _rememberKind(document.kind);
    }
    notifyListeners();
  }

  /// Ajoute un type personnalisé (sans doublon, casse ignorée). Renvoie le
  /// libellé retenu, éventuellement celui d'un type existant.
  String addCustomKind(String value) {
    final cleaned = value.trim();
    final existing = kinds.where(
      (kind) => kind.toLowerCase() == cleaned.toLowerCase(),
    );
    if (existing.isNotEmpty) return existing.first;

    _rememberKind(cleaned);
    _saveKinds();
    notifyListeners();
    return cleaned;
  }

  void removeCustomKind(String value) {
    if (!_customKinds.remove(value)) return;
    _saveKinds();
    notifyListeners();
  }

  void _rememberKind(String value) {
    final cleaned = value.trim();
    if (cleaned.isEmpty ||
        kinds.any((kind) => kind.toLowerCase() == cleaned.toLowerCase())) {
      return;
    }
    _customKinds.add(cleaned);
    if (_customKinds.length > maxCustomKinds) _customKinds.removeAt(0);
  }

  void addDocument({
    required String title,
    required String kind,
    String scope = 'company',
    String? link,
    String? note,
    String? fileName,
    String? filePath,
    int? fileSizeBytes,
  }) {
    if (_documents.length >= maxDocuments) {
      _documents.removeLast();
    }

    final document = CompanyDocument(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title.trim(),
      kind: kind.trim(),
      scope: scope.trim().isEmpty ? 'company' : scope.trim(),
      link: _cleanOptional(link),
      note: _cleanOptional(note),
      fileName: _cleanOptional(fileName),
      filePath: _cleanOptional(filePath),
      fileSizeBytes: fileSizeBytes,
    );

    _documents.insert(0, document);
    _save();
    notifyListeners();
  }

  void deleteDocument(String documentId) {
    _documents.removeWhere((document) => document.id == documentId);
    _save();
    notifyListeners();
  }

  void _save() {
    unawaited(_storage.save(_documents));
  }

  void _saveKinds() {
    unawaited(_storage.saveKinds(_customKinds));
  }

  String? _cleanOptional(String? value) {
    final cleaned = value?.trim();
    if (cleaned == null || cleaned.isEmpty) return null;
    return cleaned;
  }
}

abstract interface class CompanyDocumentsStorage {
  Future<List<CompanyDocument>> read();

  Future<void> save(List<CompanyDocument> documents);

  Future<List<String>> readKinds();

  Future<void> saveKinds(List<String> kinds);
}

class SecureCompanyDocumentsStorage implements CompanyDocumentsStorage {
  SecureCompanyDocumentsStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _documentsKey = 'studyflow.company.documents';
  static const _kindsKey = 'studyflow.company.document-kinds';

  final FlutterSecureStorage _storage;

  @override
  Future<List<CompanyDocument>> read() async {
    final rawDocuments = await _storage.read(key: _documentsKey);
    if (rawDocuments == null) return const [];

    final decoded = jsonDecode(rawDocuments);
    if (decoded is! List<Object?>) return const [];

    return decoded
        .whereType<Map<String, Object?>>()
        .map(CompanyDocument.fromJson)
        .toList(growable: false);
  }

  @override
  Future<void> save(List<CompanyDocument> documents) {
    final jsonDocuments = documents
        .map((document) => document.toJson())
        .toList();
    return _storage.write(key: _documentsKey, value: jsonEncode(jsonDocuments));
  }

  @override
  Future<List<String>> readKinds() async {
    final raw = await _storage.read(key: _kindsKey);
    if (raw == null) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List<Object?>) return const [];
    return decoded.whereType<String>().toList(growable: false);
  }

  @override
  Future<void> saveKinds(List<String> kinds) {
    return _storage.write(key: _kindsKey, value: jsonEncode(kinds));
  }
}

class MemoryCompanyDocumentsStorage implements CompanyDocumentsStorage {
  List<CompanyDocument> _documents = const [];
  List<String> _kinds = const [];

  @override
  Future<List<String>> readKinds() async => _kinds;

  @override
  Future<void> saveKinds(List<String> kinds) async {
    _kinds = List.unmodifiable(kinds);
  }

  @override
  Future<List<CompanyDocument>> read() async => _documents;

  @override
  Future<void> save(List<CompanyDocument> documents) async {
    _documents = List.unmodifiable(documents);
  }
}
