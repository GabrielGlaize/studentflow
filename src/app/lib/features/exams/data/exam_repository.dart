import 'dart:typed_data';

import 'package:studyflow_app/features/exams/domain/exam_models.dart';

abstract interface class ExamRepository {
  /// Partiels visibles : ouverts pour tous, et en préparation pour un délégué.
  Future<List<ExamSession>> listSessions({String? accessToken});

  Future<ExamSession> createSession({
    required ExamSessionDraft draft,
    String? accessToken,
  });

  Future<ExamSession> updateSession({
    required String sessionId,
    required ExamSessionDraft draft,
    String? accessToken,
  });

  Future<void> deleteSession({required String sessionId, String? accessToken});

  Future<ExamSubjectSheet> getSheet({
    required String examSubjectId,
    String? accessToken,
  });

  Future<RevisionItem> addItem({
    required String examSubjectId,
    required String text,
    String? accessToken,
  });

  Future<RevisionItem> updateItem({
    required String itemId,
    required String text,
    String? accessToken,
  });

  Future<void> deleteItem({required String itemId, String? accessToken});

  Future<void> setItemChecked({
    required String itemId,
    required bool checked,
    String? accessToken,
  });

  Future<RevisionResource> addLink({
    required String examSubjectId,
    required String url,
    String? title,
    String? accessToken,
  });

  Future<RevisionResource> addFile({
    required String examSubjectId,
    required String fileName,
    required List<int> bytes,
    String? title,
    String? accessToken,
  });

  Future<Uint8List> downloadFile({
    required String resourceId,
    String? accessToken,
  });

  Future<void> deleteResource({
    required String resourceId,
    String? accessToken,
  });
}
