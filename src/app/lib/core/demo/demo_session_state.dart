abstract final class DemoSessionState {
  static const classMemberToken = 'demo-access-token-class-member';
  static const noClassToken = 'demo-access-token-no-class';
  static const createdClassToken = 'demo-access-token-created-class';

  static bool hasNoClass(String? accessToken) => accessToken == noClassToken;
  static bool hasCreatedClass(String? accessToken) =>
      accessToken == createdClassToken;
}
