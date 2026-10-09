import 'dart:convert';
import 'dart:typed_data';

import 'package:studyflow_app/core/demo/demo_session_state.dart';
import 'package:studyflow_app/features/exams/data/exam_repository.dart';
import 'package:studyflow_app/features/exams/domain/exam_models.dart';

/// Partiels de démonstration : une session qui s'ouvre, avec une fiche déjà
/// commencée par la classe (points à réviser, artefact Claude, PDF).
class DemoExamRepository implements ExamRepository {
  const DemoExamRepository();

  static _DemoSession? _session;
  static bool _seeded = false;
  static final Map<String, List<RevisionItem>> _items = {};
  static final Map<String, List<RevisionResource>> _resources = {};
  static final Map<String, Uint8List> _files = {};
  static int _nextId = 1;

  @override
  Future<List<ExamSession>> listSessions({String? accessToken}) async {
    await Future<void>.delayed(const Duration(milliseconds: 160));
    if (DemoSessionState.hasNoClass(accessToken)) return const [];
    _seedIfNeeded();
    final session = _session;
    return session == null ? const [] : [_toSession(session)];
  }

  @override
  Future<ExamSession> createSession({
    required ExamSessionDraft draft,
    String? accessToken,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 160));
    _seeded = true;
    _session = _DemoSession(id: 'exam-${_nextId++}', draft: draft);
    return _toSession(_session!);
  }

  @override
  Future<ExamSession> updateSession({
    required String sessionId,
    required ExamSessionDraft draft,
    String? accessToken,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 160));
    final kept = {for (final s in draft.subjects) s.subjectId};
    for (final subject in _session?.draft.subjects ?? <ExamSubjectDraft>[]) {
      if (!kept.contains(subject.subjectId)) {
        _items.remove(_subjectKey(sessionId, subject.subjectId));
        _resources.remove(_subjectKey(sessionId, subject.subjectId));
      }
    }
    _session = _DemoSession(id: sessionId, draft: draft);
    return _toSession(_session!);
  }

  @override
  Future<void> deleteSession({
    required String sessionId,
    String? accessToken,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    _session = null;
    _items.clear();
    _resources.clear();
  }

  @override
  Future<ExamSubjectSheet> getSheet({
    required String examSubjectId,
    String? accessToken,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 140));
    final session = _session!;
    final subject = session.draft.subjects.firstWhere(
      (x) => _subjectKey(session.id, x.subjectId) == examSubjectId,
    );
    return ExamSubjectSheet(
      id: examSubjectId,
      sessionId: session.id,
      sessionTitle: session.draft.title,
      subjectId: subject.subjectId,
      name: subject.name,
      examDay: subject.examDay,
      startsAt: subject.startsAt,
      details: subject.details,
      canContribute: true,
      items: List.of(_items[examSubjectId] ?? const []),
      resources: List.of(_resources[examSubjectId] ?? const []),
    );
  }

  @override
  Future<RevisionItem> addItem({
    required String examSubjectId,
    required String text,
    String? accessToken,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final item = RevisionItem(
      id: 'item-${_nextId++}',
      text: text.trim(),
      authorName: 'Gabriel D.',
      isMine: true,
      canEdit: true,
      checkedByMe: false,
      checkCount: 0,
    );
    (_items[examSubjectId] ??= []).add(item);
    return item;
  }

  @override
  Future<RevisionItem> updateItem({
    required String itemId,
    required String text,
    String? accessToken,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    return _replaceItem(itemId, (item) => item.copyWith(text: text.trim()));
  }

  @override
  Future<void> deleteItem({required String itemId, String? accessToken}) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    for (final items in _items.values) {
      items.removeWhere((x) => x.id == itemId);
    }
  }

  @override
  Future<void> setItemChecked({
    required String itemId,
    required bool checked,
    String? accessToken,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    _replaceItem(itemId, (item) {
      if (item.checkedByMe == checked) return item;
      return item.copyWith(
        checkedByMe: checked,
        checkCount: item.checkCount + (checked ? 1 : -1),
      );
    });
  }

  @override
  Future<RevisionResource> addLink({
    required String examSubjectId,
    required String url,
    String? title,
    String? accessToken,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final problem = RevisionLinkRules.check(url);
    if (problem != null) throw StateError(problem);

    final resource = RevisionResource(
      id: 'resource-${_nextId++}',
      kind: RevisionResourceKind.link,
      title: (title?.trim().isNotEmpty ?? false)
          ? title!.trim()
          : Uri.parse(url.trim()).host,
      url: url.trim(),
      authorName: 'Gabriel D.',
      isMine: true,
      canEdit: true,
    );
    (_resources[examSubjectId] ??= []).insert(0, resource);
    return resource;
  }

  @override
  Future<RevisionResource> addFile({
    required String examSubjectId,
    required String fileName,
    required List<int> bytes,
    String? title,
    String? accessToken,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 160));
    final problem = RevisionFileRules.check(fileName, bytes.length);
    if (problem != null) throw StateError(problem);

    final extension = fileName.split('.').last.toLowerCase();
    final resource = RevisionResource(
      id: 'resource-${_nextId++}',
      kind: RevisionResourceKind.file,
      title: (title?.trim().isNotEmpty ?? false)
          ? title!.trim()
          : fileName.replaceAll(RegExp(r'\.[^.]+$'), ''),
      fileName: fileName,
      fileType: switch (extension) {
        'pdf' => 'pdf',
        'html' || 'htm' => 'html',
        'txt' || 'md' => 'text',
        _ => 'image',
      },
      sizeBytes: bytes.length,
      authorName: 'Gabriel D.',
      isMine: true,
      canEdit: true,
    );
    _files[resource.id] = Uint8List.fromList(bytes);
    (_resources[examSubjectId] ??= []).insert(0, resource);
    return resource;
  }

  @override
  Future<Uint8List> downloadFile({
    required String resourceId,
    String? accessToken,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return _files[resourceId] ?? Uint8List(0);
  }

  @override
  Future<void> deleteResource({
    required String resourceId,
    String? accessToken,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    for (final resources in _resources.values) {
      resources.removeWhere((x) => x.id == resourceId);
    }
    _files.remove(resourceId);
  }

  RevisionItem _replaceItem(
    String itemId,
    RevisionItem Function(RevisionItem item) update,
  ) {
    for (final items in _items.values) {
      final index = items.indexWhere((x) => x.id == itemId);
      if (index >= 0) return items[index] = update(items[index]);
    }
    throw StateError('Point introuvable.');
  }

  ExamSession _toSession(_DemoSession session) {
    final draft = session.draft;
    final today = DateTime.now();
    final opensOn = DateTime(
      draft.startsOn.year,
      draft.startsOn.month,
      draft.startsOn.day - 14,
    );
    final day = DateTime(today.year, today.month, today.day);

    return ExamSession(
      id: session.id,
      title: draft.title,
      startsOn: draft.startsOn,
      endsOn: draft.endsOn,
      opensOn: opensOn,
      isOpen: !day.isBefore(opensOn) && !day.isAfter(draft.endsOn),
      canContribute: !day.isAfter(draft.endsOn),
      subjects: [
        for (final subject in draft.subjects) _summary(session.id, subject),
      ],
    );
  }

  ExamSubjectSummary _summary(String sessionId, ExamSubjectDraft subject) {
    final key = _subjectKey(sessionId, subject.subjectId);
    final items = _items[key] ?? const <RevisionItem>[];
    final resources = _resources[key] ?? const <RevisionResource>[];
    return ExamSubjectSummary(
      id: key,
      subjectId: subject.subjectId,
      name: subject.name,
      examDay: subject.examDay,
      startsAt: subject.startsAt,
      details: subject.details,
      itemCount: items.length,
      checkedByMeCount: items.where((x) => x.checkedByMe).length,
      resourceCount: resources.length,
      contributorCount: {
        ...items.map((x) => x.authorName),
        ...resources.map((x) => x.authorName),
      }.length,
    );
  }

  static String _subjectKey(String sessionId, String subjectId) =>
      '$sessionId-$subjectId';

  void _seedIfNeeded() {
    if (_seeded) return;
    _seeded = true;

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day + 9);
    DateTime on(int offset) =>
        DateTime(start.year, start.month, start.day + offset);

    final session = _DemoSession(
      id: 'exam-demo',
      draft: ExamSessionDraft(
        title: 'Partiels du semestre 1',
        startsOn: start,
        endsOn: on(3),
        subjects: [
          ExamSubjectDraft(
            subjectId: 'subject-1',
            name: 'Mathématiques',
            examDay: start,
            startsAt: '09:00',
            details: 'Écrit 2 h · calculatrice autorisée',
          ),
          ExamSubjectDraft(
            subjectId: 'subject-2',
            name: 'Développement',
            examDay: on(1),
            startsAt: '14:00',
            details: 'Projet + oral 20 min',
          ),
          ExamSubjectDraft(
            subjectId: 'subject-3',
            name: 'Réseaux',
            examDay: on(3),
            startsAt: '10:00',
            details: 'QCM 1 h',
          ),
        ],
      ),
    );
    _session = session;

    final maths = _subjectKey(session.id, 'subject-1');
    _items[maths] = [
      const RevisionItem(
        id: 'item-demo-1',
        text: 'Chapitre 3 : intégrales et primitives',
        authorName: 'Léa M.',
        isMine: false,
        canEdit: true,
        checkedByMe: true,
        checkCount: 12,
      ),
      const RevisionItem(
        id: 'item-demo-2',
        text: 'Savoir refaire les exercices du TD 4 (suites)',
        authorName: 'Sami K.',
        isMine: false,
        canEdit: true,
        checkedByMe: false,
        checkCount: 7,
      ),
      const RevisionItem(
        id: 'item-demo-3',
        text: 'Formules de dérivation à connaître par cœur',
        authorName: 'Gabriel D.',
        isMine: true,
        canEdit: true,
        checkedByMe: false,
        checkCount: 3,
      ),
    ];
    _resources[maths] = [
      const RevisionResource(
        id: 'resource-demo-1',
        kind: RevisionResourceKind.link,
        title: 'Quiz interactif sur les intégrales',
        url: 'https://claude.ai/public/artifacts/demo-integrales',
        authorName: 'Léa M.',
        isMine: false,
        canEdit: true,
      ),
      const RevisionResource(
        id: 'resource-demo-2',
        kind: RevisionResourceKind.file,
        title: 'Fiche formules',
        fileName: 'fiche-formules.txt',
        fileType: 'text',
        sizeBytes: 1200,
        authorName: 'Sami K.',
        isMine: false,
        canEdit: true,
      ),
    ];
    _files['resource-demo-2'] = Uint8List.fromList(
      utf8.encode(
        'Dérivées usuelles\n(x^n)\' = n·x^(n-1)\n(e^x)\' = e^x\n(ln x)\' = 1/x',
      ),
    );
    _items[_subjectKey(session.id, 'subject-2')] = [
      const RevisionItem(
        id: 'item-demo-4',
        text: 'Revoir la navigation et la gestion d’état en Flutter',
        authorName: 'Léa M.',
        isMine: false,
        canEdit: true,
        checkedByMe: false,
        checkCount: 5,
      ),
    ];
  }
}

class _DemoSession {
  _DemoSession({required this.id, required this.draft});

  final String id;
  final ExamSessionDraft draft;
}
