import 'package:flutter/foundation.dart';
import 'package:studyflow_app/features/auth/data/auth_repository.dart';
import 'package:studyflow_app/features/auth/data/session_storage.dart';
import 'package:studyflow_app/features/auth/domain/auth_models.dart';

enum SessionStatus { checkingSession, signedOut, signingIn, signedIn }

class SessionController extends ChangeNotifier {
  SessionController({
    required AuthRepository authRepository,
    required SessionStorage sessionStorage,
  }) : _authRepository = authRepository,
       _sessionStorage = sessionStorage;

  final AuthRepository _authRepository;
  final SessionStorage _sessionStorage;

  static const _expiredMessage = 'Session expirée. Reconnecte-toi.';

  SessionStatus _status = SessionStatus.checkingSession;
  AuthSession? _session;
  String? _errorMessage;
  Future<String>? _refreshInFlight;

  /// Exécuté avant de révoquer la session, avec un access token encore valide
  /// (par exemple pour retirer l'appareil des notifications push).
  Future<void> Function(String accessToken)? beforeLogout;

  SessionStatus get status => _status;
  AuthSession? get session => _session;
  String? get errorMessage => _errorMessage;
  bool get isSignedIn => _session != null;

  Future<void> restoreSession() async {
    _status = SessionStatus.checkingSession;
    notifyListeners();

    try {
      _session = await _sessionStorage.read();
    } on Exception {
      // Stockage illisible (format ancien ou corrompu) : on repart d'une session vide.
      await _sessionStorage.clear();
      _session = null;
    }

    _status = _session == null
        ? SessionStatus.signedOut
        : SessionStatus.signedIn;

    if (_session != null && _session!.shouldRefresh()) {
      try {
        await _refreshAccessToken();
      } on AuthException {
        // Session refusée : _expireSession a déjà déconnecté l'utilisateur.
        // Serveur injoignable : on garde la session, le renouvellement sera
        // retenté à la prochaine requête (ouverture de l'app hors connexion).
      }
    }

    notifyListeners();
  }

  Future<bool> login({required String email, required String password}) async {
    _status = SessionStatus.signingIn;
    _errorMessage = null;
    notifyListeners();

    try {
      _session = await _authRepository.login(email: email, password: password);
      await _sessionStorage.save(_session!);
      _status = SessionStatus.signedIn;
      notifyListeners();
      return true;
    } on Exception catch (error) {
      _session = null;
      _status = SessionStatus.signedOut;
      _errorMessage = error.toString();
    }

    notifyListeners();
    return false;
  }

  Future<bool> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    _status = SessionStatus.signingIn;
    _errorMessage = null;
    notifyListeners();

    try {
      _session = await _authRepository.register(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
      );
      await _sessionStorage.save(_session!);
      _status = SessionStatus.signedIn;
      notifyListeners();
      return true;
    } on Exception catch (error) {
      _session = null;
      _status = SessionStatus.signedOut;
      _errorMessage = error.toString();
    }

    notifyListeners();
    return false;
  }

  Future<bool> registerAndCreateClass({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String schoolClassName,
    required String schoolYear,
  }) async {
    _status = SessionStatus.signingIn;
    _errorMessage = null;
    notifyListeners();

    try {
      _session = await _authRepository.registerAndCreateClass(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        schoolClassName: schoolClassName,
        schoolYear: schoolYear,
      );
      await _sessionStorage.save(_session!);
      _status = SessionStatus.signedIn;
      notifyListeners();
      return true;
    } on Exception catch (error) {
      _session = null;
      _status = SessionStatus.signedOut;
      _errorMessage = error.toString();
    }

    notifyListeners();
    return false;
  }

  Future<String?> accessTokenForApi() async {
    final currentSession = _session;
    if (currentSession == null) return null;

    if (!currentSession.shouldRefresh()) {
      return currentSession.accessToken;
    }

    return _refreshAccessToken();
  }

  /// Branché sur `ApiClient.onAccessTokenRejected` : le serveur a refusé un
  /// access token encore valide en apparence (rôle ou classe modifiés).
  Future<String?> renewRejectedAccessToken(String rejectedAccessToken) async {
    final currentSession = _session;
    if (currentSession == null) return null;

    // Une autre requête a déjà renouvelé le jeton : inutile de recommencer.
    if (currentSession.accessToken != rejectedAccessToken) {
      return currentSession.accessToken;
    }

    try {
      return await _refreshAccessToken();
    } on AuthException {
      return null;
    }
  }

  /// Un seul renouvellement à la fois : le refresh token est à usage unique,
  /// deux appels simultanés feraient échouer le second et déconnecteraient
  /// l'utilisateur.
  Future<String> _refreshAccessToken() {
    final inFlight = _refreshInFlight ??= _performRefresh().whenComplete(() {
      _refreshInFlight = null;
    });
    return inFlight;
  }

  Future<String> _performRefresh() async {
    final currentSession = _session;
    if (currentSession == null) {
      throw const AuthException(_expiredMessage, statusCode: 401);
    }

    final AuthTokenPair refreshedTokens;
    try {
      refreshedTokens = await _authRepository.refresh(
        currentSession.refreshToken,
      );
    } on AuthException catch (error) {
      if (!error.isSessionRejected) rethrow;
      await _expireSession();
      throw const AuthException(_expiredMessage, statusCode: 401);
    } on Exception {
      throw const AuthException('Impossible de renouveler la session.');
    }

    // L'utilisateur a pu se déconnecter pendant l'appel.
    final sessionAfterRefresh = _session;
    if (sessionAfterRefresh == null) {
      throw const AuthException(_expiredMessage, statusCode: 401);
    }

    _session = sessionAfterRefresh.copyWithTokens(refreshedTokens);
    await _sessionStorage.save(_session!);
    notifyListeners();
    return _session!.accessToken;
  }

  Future<void> _expireSession() async {
    await _sessionStorage.clear();
    _session = null;
    _status = SessionStatus.signedOut;
    _errorMessage = _expiredMessage;
    notifyListeners();
  }

  Future<PasswordResetRequestResult> requestPasswordReset({
    required String email,
  }) {
    return _authRepository.requestPasswordReset(email: email);
  }

  Future<void> resetPassword({
    required String email,
    required String token,
    required String newPassword,
  }) {
    return _authRepository.resetPassword(
      email: email,
      token: token,
      newPassword: newPassword,
    );
  }

  Future<void> replaceSession(AuthSession session) async {
    _session = session;
    await _sessionStorage.save(session);
    _status = SessionStatus.signedIn;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      // L'API exige un access token valide pour révoquer le refresh token :
      // sans cela, la session resterait utilisable 30 jours côté serveur.
      final accessToken = await accessTokenForApi();
      if (accessToken != null) await beforeLogout?.call(accessToken);
      final sessionToRevoke = _session;
      if (sessionToRevoke != null) {
        await _authRepository.logout(sessionToRevoke);
      }
    } on Exception {
      // Local logout must remain possible even if the remote session cannot be
      // revoked immediately, for example when the user is offline.
    } finally {
      await _sessionStorage.clear();
    }

    _session = null;
    _status = SessionStatus.signedOut;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> deleteAccount() async {
    await accessTokenForApi();
    final sessionToDelete = _session;
    if (sessionToDelete == null) return;

    await _authRepository.deleteAccount(sessionToDelete);
    await _sessionStorage.clear();
    _session = null;
    _status = SessionStatus.signedOut;
    _errorMessage = null;
    notifyListeners();
  }
}
