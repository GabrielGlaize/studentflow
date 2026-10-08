class ClassSubject {
  const ClassSubject({
    required this.id,
    required this.name,
    required this.isActive,
    this.teacherIds = const [],
  });

  final String id;
  final String name;
  final bool isActive;

  /// Intervenants rattachés à cette matière (une matière peut en avoir plusieurs).
  final List<String> teacherIds;

  factory ClassSubject.fromJson(Map<String, Object?> json) {
    return ClassSubject(
      id: json['id'] as String,
      name: json['name'] as String,
      isActive: json['isActive'] as bool? ?? true,
      teacherIds: _readIds(json['teacherIds']),
    );
  }

  ClassSubject copyWith({String? name, List<String>? teacherIds}) {
    return ClassSubject(
      id: id,
      name: name ?? this.name,
      isActive: isActive,
      teacherIds: teacherIds ?? this.teacherIds,
    );
  }
}

class ClassTeacher {
  const ClassTeacher({
    required this.id,
    required this.displayName,
    required this.isActive,
    this.information,
    this.subjectIds = const [],
  });

  final String id;
  final String displayName;
  final String? information;
  final bool isActive;

  /// Matières enseignées par cet intervenant (il peut en avoir plusieurs).
  final List<String> subjectIds;

  TeacherName get name => TeacherName.parse(displayName);

  factory ClassTeacher.fromJson(Map<String, Object?> json) {
    return ClassTeacher(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      information: json['information'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      subjectIds: _readIds(json['subjectIds']),
    );
  }

  ClassTeacher copyWith({
    String? displayName,
    String? information,
    List<String>? subjectIds,
  }) {
    return ClassTeacher(
      id: id,
      displayName: displayName ?? this.displayName,
      information: information ?? this.information,
      isActive: isActive,
      subjectIds: subjectIds ?? this.subjectIds,
    );
  }
}

enum TeacherCivility {
  monsieur('M.'),
  madame('Mme'),
  none('');

  const TeacherCivility(this.prefix);

  final String prefix;
}

/// Nom d'un intervenant au format de la classe : « M. Dupont », « Mme Martin ».
class TeacherName {
  const TeacherName({required this.civility, required this.lastName});

  final TeacherCivility civility;
  final String lastName;

  String get displayName {
    final cleaned = _capitalize(lastName.trim());
    return civility == TeacherCivility.none
        ? cleaned
        : '${civility.prefix} $cleaned';
  }

  static TeacherName parse(String displayName) {
    final trimmed = displayName.trim();
    final lower = trimmed.toLowerCase();
    for (final (prefixes, civility) in const [
      (['m. ', 'm ', 'mr ', 'mr. ', 'monsieur '], TeacherCivility.monsieur),
      (['mme ', 'mme. ', 'madame ', 'mlle '], TeacherCivility.madame),
    ]) {
      for (final prefix in prefixes) {
        if (lower.startsWith(prefix)) {
          return TeacherName(
            civility: civility,
            lastName: trimmed.substring(prefix.length).trim(),
          );
        }
      }
    }

    return TeacherName(civility: TeacherCivility.none, lastName: trimmed);
  }

  static String _capitalize(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }
}

List<String> _readIds(Object? value) {
  if (value is! List) return const [];
  return value.whereType<String>().toList(growable: false);
}
