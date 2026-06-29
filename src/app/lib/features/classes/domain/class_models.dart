class CurrentClassInfo {
  const CurrentClassInfo({
    required this.id,
    required this.name,
    required this.schoolYear,
    required this.isDelegate,
    this.accessCode,
    this.accessCodeUpdatedAt,
  });

  final String id;
  final String name;
  final String schoolYear;
  final bool isDelegate;
  final String? accessCode;
  final DateTime? accessCodeUpdatedAt;

  factory CurrentClassInfo.fromJson(Map<String, Object?> json) {
    return CurrentClassInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      schoolYear: json['schoolYear'] as String,
      isDelegate: json['isDelegate'] as bool? ?? false,
      accessCode: json['accessCode'] as String?,
      accessCodeUpdatedAt: json['accessCodeUpdatedAt'] == null
          ? null
          : DateTime.parse(json['accessCodeUpdatedAt'] as String),
    );
  }
}

class ClassAccessCode {
  const ClassAccessCode({required this.accessCode, required this.updatedAt});

  final String accessCode;
  final DateTime updatedAt;

  factory ClassAccessCode.fromJson(Map<String, Object?> json) {
    return ClassAccessCode(
      accessCode: json['accessCode'] as String,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

class PendingMembershipRequest {
  const PendingMembershipRequest({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String email;

  String get displayName => '$firstName $lastName'.trim();

  factory PendingMembershipRequest.fromJson(Map<String, Object?> json) {
    return PendingMembershipRequest(
      id: json['id'] as String,
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String,
      email: json['email'] as String,
    );
  }
}

class ClassMember {
  const ClassMember({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.isDelegate,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final bool isDelegate;

  String get displayName => '$firstName $lastName'.trim();

  factory ClassMember.fromJson(Map<String, Object?> json) {
    return ClassMember(
      id: json['id'] as String,
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String,
      email: json['email'] as String,
      isDelegate: json['isDelegate'] as bool? ?? false,
    );
  }
}
