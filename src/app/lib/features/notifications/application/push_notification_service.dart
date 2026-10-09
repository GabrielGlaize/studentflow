import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:studyflow_app/features/auth/application/session_controller.dart';
import 'package:studyflow_app/features/notifications/application/notification_channel.dart';
import 'package:studyflow_app/features/notifications/data/notification_device_repository.dart';

/// Relie l'appareil au compte connecté pour recevoir les notifications envoyées
/// par l'API (rappels de cours et de devoirs, annonces de la classe).
///
/// Application fermée ou en arrière-plan, Android affiche lui-même la
/// notification. Au premier plan, Firebase la transmet à l'application : on
/// l'affiche alors via flutter_local_notifications.
class PushNotificationService {
  PushNotificationService({
    required SessionController sessionController,
    required NotificationDeviceRepository deviceRepository,
    required FirebaseOptions? firebaseOptions,
    FlutterLocalNotificationsPlugin? localNotifications,
  }) : _sessionController = sessionController,
       _deviceRepository = deviceRepository,
       _firebaseOptions = firebaseOptions,
       _localNotifications =
           localNotifications ?? FlutterLocalNotificationsPlugin();

  final SessionController _sessionController;
  final NotificationDeviceRepository _deviceRepository;
  final FirebaseOptions? _firebaseOptions;
  final FlutterLocalNotificationsPlugin _localNotifications;

  bool _started = false;
  bool _registering = false;
  String? _token;
  String? _registeredUserId;
  String? _deviceId;

  bool get isAvailable => _firebaseOptions != null;

  /// Cet appareil est enregistré côté serveur : les rappels arrivent en push.
  bool get isRegistered => _deviceId != null;

  Future<void> start() async {
    final options = _firebaseOptions;
    if (options == null || _started) return;
    _started = true;

    try {
      await Firebase.initializeApp(options: options);
      await _prepareLocalNotifications();

      FirebaseMessaging.onMessage.listen(
        (message) => unawaited(_showInForeground(message)),
      );
      FirebaseMessaging.instance.onTokenRefresh.listen((token) {
        _token = token;
        _registeredUserId = null;
        unawaited(_syncRegistration());
      });

      _sessionController.addListener(_onSessionChanged);
      await _syncRegistration();
    } on Object catch (error) {
      // Les notifications ne doivent jamais empêcher l'application de démarrer.
      debugPrint('Notifications push indisponibles : $error');
    }
  }

  /// Appelé juste avant la déconnexion : cet appareil ne doit plus recevoir
  /// les notifications du compte qui s'en va.
  Future<void> unregister(String accessToken) async {
    final deviceId = _deviceId;
    _deviceId = null;
    _registeredUserId = null;
    if (deviceId == null) return;

    await _deviceRepository.delete(
      deviceId: deviceId,
      accessToken: accessToken,
    );
  }

  void _onSessionChanged() => unawaited(_syncRegistration());

  Future<void> _syncRegistration() async {
    final user = _sessionController.session?.user;
    if (user == null) {
      _registeredUserId = null;
      _deviceId = null;
      return;
    }
    if (_registeredUserId == user.id || _registering) return;

    _registering = true;
    try {
      final permission = await FirebaseMessaging.instance.requestPermission();
      if (permission.authorizationStatus == AuthorizationStatus.denied) return;

      final token = _token ??= await FirebaseMessaging.instance.getToken();
      if (token == null) return;

      final accessToken = await _sessionController.accessTokenForApi();
      _deviceId = await _deviceRepository.register(
        token: token,
        platform: 'android',
        accessToken: accessToken,
      );
      _registeredUserId = user.id;
    } on Object catch (error) {
      // Nouvel essai au prochain changement de session (connexion, renouvellement).
      debugPrint('Enregistrement de l’appareil impossible : $error');
    } finally {
      _registering = false;
    }
  }

  Future<void> _prepareLocalNotifications() async {
    await _localNotifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            StudyFlowNotificationChannel.id,
            StudyFlowNotificationChannel.name,
            description: StudyFlowNotificationChannel.description,
            importance: Importance.high,
          ),
        );
  }

  Future<void> _showInForeground(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    await _localNotifications.show(
      id:
          (message.messageId ?? notification.hashCode.toString()).hashCode &
          0x7fffffff,
      title: notification.title,
      body: notification.body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          StudyFlowNotificationChannel.id,
          StudyFlowNotificationChannel.name,
          channelDescription: StudyFlowNotificationChannel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }
}
