class ClassSubject {
  const ClassSubject({
    required this.id,
    required this.name,
    required this.isActive,
  });

  final String id;
  final String name;
  final bool isActive;

  factory ClassSubject.fromJson(Map<String, Object?> json) {
    return ClassSubject(
      id: json['id'] as String,
      name: json['name'] as String,
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}

class ClassTeacher {
  const ClassTeacher({
    required this.id,
    required this.displayName,
    required this.isActive,
    this.information,
  });

  final String id;
  final String displayName;
  final String? information;
  final bool isActive;

  factory ClassTeacher.fromJson(Map<String, Object?> json) {
    return ClassTeacher(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      information: json['information'] as String?,
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}
