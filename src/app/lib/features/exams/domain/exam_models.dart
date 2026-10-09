/// Partiels d'une classe : période, épreuves et fiches de révision partagées.
library;

class ExamSession {
  const ExamSession({
    required this.id,
    required this.title,
    required this.startsOn,
    required this.endsOn,
    required this.opensOn,
    required this.isOpen,
    required this.canContribute,
    required this.subjects,
  });

  final String id;
  final String title;
  final DateTime startsOn;
  final DateTime endsOn;

  /// Jour où la fiche s'ouvre à toute la classe (deux semaines avant).
  final DateTime opensOn;
  final bool isOpen;
  final bool canContribute;
  final List<ExamSubjectSummary> subjects;

  int get itemCount => subjects.fold(0, (sum, x) => sum + x.itemCount);

  int get checkedCount =>
      subjects.fold(0, (sum, x) => sum + x.checkedByMeCount);

  double get progress => itemCount == 0 ? 0 : checkedCount / itemCount;

  /// Jours avant la première épreuve (0 le jour même, négatif pendant).
  int daysUntilStart(DateTime now) => DateTime(
    startsOn.year,
    startsOn.month,
    startsOn.day,
  ).difference(DateTime(now.year, now.month, now.day)).inDays;

  bool isRunning(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return !today.isBefore(startsOn) && !today.isAfter(endsOn);
  }

  factory ExamSession.fromJson(Map<String, Object?> json) {
    return ExamSession(
      id: json['id'] as String,
      title: json['title'] as String,
      startsOn: DateTime.parse(json['startsOn'] as String),
      endsOn: DateTime.parse(json['endsOn'] as String),
      opensOn: DateTime.parse(json['opensOn'] as String),
      isOpen: json['isOpen'] as bool? ?? false,
      canContribute: json['canContribute'] as bool? ?? false,
      subjects: (json['subjects'] as List<Object?>? ?? const [])
          .whereType<Map<String, Object?>>()
          .map(ExamSubjectSummary.fromJson)
          .toList(growable: false),
    );
  }
}

class ExamSubjectSummary {
  const ExamSubjectSummary({
    required this.id,
    required this.subjectId,
    required this.name,
    required this.itemCount,
    required this.checkedByMeCount,
    required this.resourceCount,
    required this.contributorCount,
    this.examDay,
    this.startsAt,
    this.details,
  });

  final String id;
  final String subjectId;
  final String name;
  final DateTime? examDay;

  /// « 09:00 ».
  final String? startsAt;
  final String? details;
  final int itemCount;
  final int checkedByMeCount;
  final int resourceCount;
  final int contributorCount;

  double get progress => itemCount == 0 ? 0 : checkedByMeCount / itemCount;

  factory ExamSubjectSummary.fromJson(Map<String, Object?> json) {
    return ExamSubjectSummary(
      id: json['id'] as String,
      subjectId: json['subjectId'] as String,
      name: json['name'] as String,
      examDay: _date(json['examDay']),
      startsAt: _shortTime(json['startsAt']),
      details: json['details'] as String?,
      itemCount: (json['itemCount'] as num?)?.toInt() ?? 0,
      checkedByMeCount: (json['checkedByMeCount'] as num?)?.toInt() ?? 0,
      resourceCount: (json['resourceCount'] as num?)?.toInt() ?? 0,
      contributorCount: (json['contributorCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class ExamSubjectSheet {
  const ExamSubjectSheet({
    required this.id,
    required this.sessionId,
    required this.sessionTitle,
    required this.subjectId,
    required this.name,
    required this.canContribute,
    required this.items,
    required this.resources,
    this.examDay,
    this.startsAt,
    this.details,
  });

  final String id;
  final String sessionId;
  final String sessionTitle;
  final String subjectId;
  final String name;
  final DateTime? examDay;
  final String? startsAt;
  final String? details;
  final bool canContribute;
  final List<RevisionItem> items;
  final List<RevisionResource> resources;

  int get checkedCount => items.where((x) => x.checkedByMe).length;

  factory ExamSubjectSheet.fromJson(Map<String, Object?> json) {
    return ExamSubjectSheet(
      id: json['id'] as String,
      sessionId: json['sessionId'] as String,
      sessionTitle: json['sessionTitle'] as String,
      subjectId: json['subjectId'] as String,
      name: json['name'] as String,
      examDay: _date(json['examDay']),
      startsAt: _shortTime(json['startsAt']),
      details: json['details'] as String?,
      canContribute: json['canContribute'] as bool? ?? false,
      items: (json['items'] as List<Object?>? ?? const [])
          .whereType<Map<String, Object?>>()
          .map(RevisionItem.fromJson)
          .toList(),
      resources: (json['resources'] as List<Object?>? ?? const [])
          .whereType<Map<String, Object?>>()
          .map(RevisionResource.fromJson)
          .toList(),
    );
  }
}

/// Un point à réviser. La case « révisé » est personnelle.
class RevisionItem {
  const RevisionItem({
    required this.id,
    required this.text,
    required this.authorName,
    required this.isMine,
    required this.canEdit,
    required this.checkedByMe,
    required this.checkCount,
  });

  final String id;
  final String text;
  final String authorName;
  final bool isMine;
  final bool canEdit;
  final bool checkedByMe;

  /// Nombre d'élèves qui l'ont coché.
  final int checkCount;

  RevisionItem copyWith({String? text, bool? checkedByMe, int? checkCount}) {
    return RevisionItem(
      id: id,
      text: text ?? this.text,
      authorName: authorName,
      isMine: isMine,
      canEdit: canEdit,
      checkedByMe: checkedByMe ?? this.checkedByMe,
      checkCount: checkCount ?? this.checkCount,
    );
  }

  factory RevisionItem.fromJson(Map<String, Object?> json) {
    return RevisionItem(
      id: json['id'] as String,
      text: json['text'] as String,
      authorName: json['authorName'] as String,
      isMine: json['isMine'] as bool? ?? false,
      canEdit: json['canEdit'] as bool? ?? false,
      checkedByMe: json['checkedByMe'] as bool? ?? false,
      checkCount: (json['checkCount'] as num?)?.toInt() ?? 0,
    );
  }
}

enum RevisionResourceKind { link, file }

class RevisionResource {
  const RevisionResource({
    required this.id,
    required this.kind,
    required this.title,
    required this.authorName,
    required this.isMine,
    required this.canEdit,
    this.url,
    this.fileName,
    this.fileType,
    this.sizeBytes,
  });

  final String id;
  final RevisionResourceKind kind;
  final String title;
  final String? url;
  final String? fileName;

  /// pdf, image, html ou text (déterminé par le serveur).
  final String? fileType;
  final int? sizeBytes;
  final String authorName;
  final bool isMine;
  final bool canEdit;

  bool get isLink => kind == RevisionResourceKind.link;

  RevisionLinkKind get linkKind => RevisionLinkKind.of(url);

  factory RevisionResource.fromJson(Map<String, Object?> json) {
    return RevisionResource(
      id: json['id'] as String,
      kind: json['kind'] == 'file'
          ? RevisionResourceKind.file
          : RevisionResourceKind.link,
      title: json['title'] as String,
      url: json['url'] as String?,
      fileName: json['fileName'] as String?,
      fileType: json['fileType'] as String?,
      sizeBytes: (json['sizeBytes'] as num?)?.toInt(),
      authorName: json['authorName'] as String,
      isMine: json['isMine'] as bool? ?? false,
      canEdit: json['canEdit'] as bool? ?? false,
    );
  }
}

/// Sites reconnus, pour un libellé et une icône parlants.
enum RevisionLinkKind {
  claude('Artefact Claude'),
  drive('Google Drive'),
  video('Vidéo YouTube'),
  github('GitHub'),
  notion('Notion'),
  quizlet('Quizlet'),
  web('Site web');

  const RevisionLinkKind(this.label);

  final String label;

  static RevisionLinkKind of(String? url) {
    final host = Uri.tryParse(url ?? '')?.host.toLowerCase() ?? '';
    bool on(String domain) => host == domain || host.endsWith('.$domain');

    if (on('claude.ai') || on('claude.site') || on('claudeusercontent.com')) {
      return claude;
    }
    if (on('docs.google.com') || on('drive.google.com')) return drive;
    if (on('youtube.com') || on('youtu.be')) return video;
    if (on('github.com') || on('github.io')) return github;
    if (on('notion.so') || on('notion.site')) return notion;
    if (on('quizlet.com')) return quizlet;
    return web;
  }
}

/// Ce que le délégué saisit pour créer ou modifier des partiels.
class ExamSessionDraft {
  const ExamSessionDraft({
    required this.title,
    required this.startsOn,
    required this.endsOn,
    required this.subjects,
  });

  final String title;
  final DateTime startsOn;
  final DateTime endsOn;
  final List<ExamSubjectDraft> subjects;

  Map<String, Object?> toJson() => {
    'title': title.trim(),
    'startsOn': _dateOnly(startsOn),
    'endsOn': _dateOnly(endsOn),
    'subjects': subjects.map((x) => x.toJson()).toList(),
  };
}

class ExamSubjectDraft {
  const ExamSubjectDraft({
    required this.subjectId,
    required this.name,
    this.examDay,
    this.startsAt,
    this.details,
  });

  final String subjectId;

  /// Affichage seulement (mode démo).
  final String name;
  final DateTime? examDay;
  final String? startsAt;
  final String? details;

  Map<String, Object?> toJson() => {
    'subjectId': subjectId,
    'examDay': examDay == null ? null : _dateOnly(examDay!),
    'startsAt': startsAt,
    'details': (details?.trim().isEmpty ?? true) ? null : details!.trim(),
  };
}

/// Contrôle côté app avant l'envoi, aligné sur la liste blanche du serveur
/// (qui vérifie aussi le contenu réel du fichier).
abstract final class RevisionFileRules {
  static const allowedExtensions = [
    'pdf',
    'png',
    'jpg',
    'jpeg',
    'webp',
    'html',
    'htm',
    'txt',
    'md',
  ];

  static const acceptedLabel = 'PDF, image (PNG, JPG, WebP), page HTML, texte';

  static const _mb = 1024 * 1024;

  /// Message d'erreur, ou null si le fichier peut être envoyé.
  static String? check(String fileName, int sizeBytes) {
    final dot = fileName.lastIndexOf('.');
    final extension = dot < 0 ? '' : fileName.substring(dot + 1).toLowerCase();
    if (!allowedExtensions.contains(extension)) {
      return extension.isEmpty
          ? 'Ce fichier n’a pas d’extension. Formats acceptés : $acceptedLabel.'
          : 'Les fichiers .$extension ne sont pas acceptés. Formats possibles : $acceptedLabel.';
    }
    if (sizeBytes == 0) return 'Le fichier est vide.';

    final max = switch (extension) {
      'pdf' => 10 * _mb,
      'html' || 'htm' => 2 * _mb,
      'txt' || 'md' => _mb,
      _ => 8 * _mb,
    };
    return sizeBytes > max
        ? 'Fichier trop lourd : ${max ~/ _mb} Mo maximum pour ce format.'
        : null;
  }

  /// « 1,2 Mo », « 340 Ko ».
  static String size(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).ceil()} Ko';
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1).replaceAll('.', ',')} Mo';
  }
}

/// Lien acceptable pour le serveur : https, sans identifiants, vers un site.
abstract final class RevisionLinkRules {
  static String? check(String value) {
    final text = value.trim();
    if (text.isEmpty) return 'Colle le lien à partager.';
    final uri = Uri.tryParse(text);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return 'Ce lien n’est pas valide. Il doit commencer par https://';
    }
    if (uri.scheme == 'http') {
      return 'Utilise un lien sécurisé, qui commence par https://';
    }
    if (uri.scheme != 'https') {
      return 'Seuls les liens web (https://) sont acceptés.';
    }
    if (uri.userInfo.isNotEmpty) {
      return 'Un lien ne doit pas contenir d’identifiant ni de mot de passe.';
    }
    if (!uri.host.contains('.')) return 'Ce lien ne mène pas à un site web.';
    return null;
  }
}

DateTime? _date(Object? value) =>
    value is String ? DateTime.parse(value) : null;

String? _shortTime(Object? value) {
  if (value is! String) return null;
  return value.length >= 5 ? value.substring(0, 5) : value;
}

String _dateOnly(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}
