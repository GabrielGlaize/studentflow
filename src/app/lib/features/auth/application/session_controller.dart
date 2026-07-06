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

  SessionStatus _status = SessionStatus.checkingSession;
  AuthSession? _session;
  String? _errorMessage;

  SessionStatus get status => _status;
  AuthSession? get session => _session;
  String? get errorMessage => _errorMessage;
  bool get isSignedIn => _session != null;

  Future<void> restoreSession() async {
    _status = SessionStatus.checkingSession;
    notifyListeners();

    try {
      _session = await _sessionStorage.read();
      if (_session == null) {
        _status = SessionStatus.signedOut;
      } else if (_session!.shouldRefresh()) {
        final refreshedTokens = await _authRepository.refresh(
          _session!.refreshToken,
        );
        _session = _session!.copyWithTokens(refreshedTokens);
        await _sessionStorage.save(_session!);
        _status = SessionStatus.signedIn;
      } else {
        _status = SessionStatus.signedIn;
      }
    } on Exception {
      await _sessionStorage.clear();
      _session = null;
      _status = SessionStatus.signedOut;
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

    try {
      final refreshedTokens = await _authRepository.refresh(
        currentSession.refreshToken,
      );
      _session = currentSession.copyWithTokens(refreshedTokens);
      await _sessionStorage.save(_session!);
      notifyListeners();
      return _session!.accessToken;
    } on Exception {
      await _sessionStorage.clear();
      _session = null;
      _status = SessionStatus.signedOut;
      _errorMessage = 'Session expirée. Reconnecte-toi.';
      notifyListeners();
      throw const AuthException('Session expirée. Reconnecte-toi.');
    }
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
    final sessionToRevoke = _session;
    try {
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
