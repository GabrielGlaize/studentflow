import 'dart:typed_data';

import 'package:studyflow_app/core/network/api_client.dart';
import 'package:studyflow_app/features/exams/data/exam_repository.dart';
import 'package:studyflow_app/features/exams/domain/exam_models.dart';

class HttpExamRepository implements ExamRepository {
  const HttpExamRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<List<ExamSession>> listSessions({String? accessToken}) async {
    final json = await _apiClient.getJsonList(
      '/api/v1/exams',
      accessToken: accessToken,
    );
    return json.map(ExamSession.fromJson).toList(growable: false);
  }

  @override
  Future<ExamSession> createSession({
    required ExamSessionDraft draft,
    String? accessToken,
  }) async {
    final json = await _apiClient.postJson(
      '/api/v1/exams',
      body: draft.toJson(),
      accessToken: accessToken,
    );
    return ExamSession.fromJson(json);
  }

  @override
  Future<ExamSession> updateSession({
    required String sessionId,
    required ExamSessionDraft draft,
    String? accessToken,
  }) async {
    final json = await _apiClient.putJson(
      '/api/v1/exams/$sessionId',
      body: draft.toJson(),
      accessToken: accessToken,
    );
    return ExamSession.fromJson(json);
  }

  @override
  Future<void> deleteSession({required String sessionId, String? accessToken}) {
    return _apiClient.deleteNoContent(
      '/api/v1/exams/$sessionId',
      accessToken: accessToken,
    );
  }

  @override
  Future<ExamSubjectSheet> getSheet({
    required String examSubjectId,
    String? accessToken,
  }) async {
    final json = await _apiClient.getJson(
      '/api/v1/exams/subjects/$examSubjectId',
      accessToken: accessToken,
    );
    return ExamSubjectSheet.fromJson(json);
  }

  @override
  Future<RevisionItem> addItem({
    required String examSubjectId,
    required String text,
    String? accessToken,
  }) async {
    final json = await _apiClient.postJson(
      '/api/v1/exams/subjects/$examSubjectId/items',
      body: {'text': text.trim()},
      accessToken: accessToken,
    );
    return RevisionItem.fromJson(json);
  }

  @override
  Future<RevisionItem> updateItem({
    required String itemId,
    required String text,
    String? accessToken,
  }) async {
    final json = await _apiClient.putJson(
      '/api/v1/exams/items/$itemId',
      body: {'text': text.trim()},
      accessToken: accessToken,
    );
    return RevisionItem.fromJson(json);
  }

  @override
  Future<void> deleteItem({required String itemId, String? accessToken}) {
    return _apiClient.deleteNoContent(
      '/api/v1/exams/items/$itemId',
      accessToken: accessToken,
    );
  }

  @override
  Future<void> setItemChecked({
    required String itemId,
    required bool checked,
    String? accessToken,
  }) {
    return _apiClient.putNoContent(
      '/api/v1/exams/items/$itemId/check',
      body: {'checked': checked},
      accessToken: accessToken,
    );
  }

  @override
  Future<RevisionResource> addLink({
    required String examSubjectId,
    required String url,
    String? title,
    String? accessToken,
  }) async {
    final json = await _apiClient.postJson(
      '/api/v1/exams/subjects/$examSubjectId/links',
      body: {'url': url.trim(), 'title': _clean(title)},
      accessToken: accessToken,
    );
    return RevisionResource.fromJson(json);
  }

  @override
  Future<RevisionResource> addFile({
    required String examSubjectId,
    required String fileName,
    required List<int> bytes,
    String? title,
    String? accessToken,
  }) async {
    final json = await _apiClient.postFile(
      '/api/v1/exams/subjects/$examSubjectId/files',
      fileName: fileName,
      bytes: bytes,
      fields: {'title': ?_clean(title)},
      accessToken: accessToken,
    );
    return RevisionResource.fromJson(json);
  }

  @override
  Future<Uint8List> downloadFile({
    required String resourceId,
    String? accessToken,
  }) {
    return _apiClient.getBytes(
      '/api/v1/exams/resources/$resourceId/file',
      accessToken: accessToken,
    );
  }

  @override
  Future<void> deleteResource({
    required String resourceId,
    String? accessToken,
  }) {
    return _apiClient.deleteNoContent(
      '/api/v1/exams/resources/$resourceId',
      accessToken: accessToken,
    );
  }

  String? _clean(String? value) {
    final cleaned = value?.trim();
    return cleaned == null || cleaned.isEmpty ? null : cleaned;
  }
}
