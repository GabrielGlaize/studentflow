class AuthSession {
  const AuthSession({required this.tokens, required this.user});

  final AuthTokenPair tokens;
  final UserSummary user;

  String get accessToken => tokens.accessToken;
  String get refreshToken => tokens.refreshToken;

  bool shouldRefresh({DateTime? now}) {
    final referenceTime = now ?? DateTime.now().toUtc();
    return tokens.accessTokenExpiresAt.isBefore(
      referenceTime.add(const Duration(minutes: 1)),
    );
  }

  AuthSession copyWithTokens(AuthTokenPair newTokens) {
    return AuthSession(tokens: newTokens, user: user);
  }

  factory AuthSession.fromJson(Map<String, Object?> json) {
    final tokens = json['tokens']! as Map<String, Object?>;

    return AuthSession(
      tokens: AuthTokenPair.fromJson(tokens),
      user: UserSummary.fromJson(json['user']! as Map<String, Object?>),
    );
  }

  Map<String, Object?> toJson() {
    return {'tokens': tokens.toJson(), 'user': user.toJson()};
  }
}

class AuthTokenPair {
  const AuthTokenPair({
    required this.accessToken,
    required this.accessTokenExpiresAt,
    required this.refreshToken,
    required this.refreshTokenExpiresAt,
  });

  final String accessToken;
  final DateTime accessTokenExpiresAt;
  final String refreshToken;
  final DateTime refreshTokenExpiresAt;

  factory AuthTokenPair.fromJson(Map<String, Object?> json) {
    return AuthTokenPair(
      accessToken: json['accessToken'] as String,
      accessTokenExpiresAt: DateTime.parse(
        json['accessTokenExpiresAt'] as String,
      ),
      refreshToken: json['refreshToken'] as String,
      refreshTokenExpiresAt: DateTime.parse(
        json['refreshTokenExpiresAt'] as String,
      ),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'accessToken': accessToken,
      'accessTokenExpiresAt': accessTokenExpiresAt.toIso8601String(),
      'refreshToken': refreshToken,
      'refreshTokenExpiresAt': refreshTokenExpiresAt.toIso8601String(),
    };
  }
}

class UserSummary {
  const UserSummary({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.roles,
    this.schoolClassId,
  });

  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String? schoolClassId;
  final List<String> roles;

  String get displayName => '$firstName $lastName'.trim();

  bool get isDelegate => roles.contains('Delegue');

  factory UserSummary.fromJson(Map<String, Object?> json) {
    return UserSummary(
      id: json['id'] as String,
      email: json['email'] as String,
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String,
      schoolClassId: json['schoolClassId'] as String?,
      roles: (json['roles'] as List<Object?>? ?? []).whereType<String>().toList(
        growable: false,
      ),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'schoolClassId': schoolClassId,
      'roles': roles,
    };
  }
}

class PasswordResetRequestResult {
  const PasswordResetRequestResult({
    required this.message,
    this.developmentToken,
    this.expiresAt,
  });

  final String message;
  final String? developmentToken;
  final DateTime? expiresAt;

  factory PasswordResetRequestResult.fromJson(Map<String, Object?> json) {
    return PasswordResetRequestResult(
      message: json['message'] as String? ?? 'Demande prise en compte.',
      developmentToken: json['developmentToken'] as String?,
      expiresAt: json['expiresAt'] == null
          ? null
          : DateTime.parse(json['expiresAt'] as String),
    );
  }
}
