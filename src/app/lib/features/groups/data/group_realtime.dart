import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:signalr_netcore/signalr_client.dart';
import 'package:studyflow_app/features/groups/domain/group_models.dart';

/// Ce que le serveur pousse à l'instant pour un groupe ouvert.
sealed class GroupRealtimeEvent {
  const GroupRealtimeEvent(this.groupId);

  final String groupId;
}

class GroupMessageEvent extends GroupRealtimeEvent {
  GroupMessageEvent(this.message) : super(message.groupId);

  final GroupMessage message;
}

class GroupMessageDeletedEvent extends GroupRealtimeEvent {
  const GroupMessageDeletedEvent(super.groupId, this.messageId);

  final String messageId;
}

/// Tâches, réunions, ressources ou membres ont changé : l'écran recharge.
class GroupChangedEvent extends GroupRealtimeEvent {
  const GroupChangedEvent(super.groupId, this.area);

  /// group, members, tasks, resources ou meetings.
  final String area;
}

class GroupReadEvent extends GroupRealtimeEvent {
  const GroupReadEvent(super.groupId, this.userId, this.readAt);

  final String userId;
  final DateTime readAt;
}

class GroupTypingEvent extends GroupRealtimeEvent {
  const GroupTypingEvent(super.groupId, this.userId);

  final String userId;
}

/// Temps réel des groupes. Si la connexion n'est pas possible (réseau, proxy),
/// [connected] reste faux et les écrans rechargent eux-mêmes régulièrement :
/// rien ne se perd, les messages sont enregistrés par l'API.
abstract class GroupRealtime {
  Stream<GroupRealtimeEvent> get events;

  ValueListenable<bool> get connected;

  /// Commence à suivre un groupe (écran du groupe ouvert).
  Future<void> watch(String groupId);

  Future<void> unwatch(String groupId);

  /// « … écrit » : envoyé au plus toutes les quelques secondes par l'écran.
  void typing(String groupId);

  Future<void> dispose();
}

/// Sans serveur (démo, tests) : les événements viennent de [emit].
class LocalGroupRealtime implements GroupRealtime {
  final _events = StreamController<GroupRealtimeEvent>.broadcast();
  final _connected = ValueNotifier(false);

  @override
  Stream<GroupRealtimeEvent> get events => _events.stream;

  @override
  ValueListenable<bool> get connected => _connected;

  void emit(GroupRealtimeEvent event) => _events.add(event);

  @override
  Future<void> watch(String groupId) async {}

  @override
  Future<void> unwatch(String groupId) async {}

  @override
  void typing(String groupId) {}

  @override
  Future<void> dispose() async {
    await _events.close();
    _connected.dispose();
  }
}

class SignalRGroupRealtime implements GroupRealtime {
  SignalRGroupRealtime({
    required String baseUrl,
    required Future<String?> Function() accessToken,
  }) : _hubUrl =
           '${baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl}/hubs/groups',
       _accessToken = accessToken;

  final String _hubUrl;
  final Future<String?> Function() _accessToken;
  final _events = StreamController<GroupRealtimeEvent>.broadcast();
  final _connected = ValueNotifier(false);
  final _watched = <String>{};
  HubConnection? _connection;
  Future<void>? _starting;

  @override
  Stream<GroupRealtimeEvent> get events => _events.stream;

  @override
  ValueListenable<bool> get connected => _connected;

  @override
  Future<void> watch(String groupId) async {
    _watched.add(groupId);
    try {
      await _ensureStarted();
      await _join(groupId);
    } on Object catch (error) {
      debugPrint('Temps réel indisponible : $error');
    }
  }

  @override
  Future<void> unwatch(String groupId) async {
    _watched.remove(groupId);
    final connection = _connection;
    if (connection == null) return;
    try {
      if (connection.state == HubConnectionState.Connected) {
        await connection.invoke('Leave', args: [groupId]);
      }
      // Plus aucun groupe ouvert : inutile de garder une connexion au serveur.
      if (_watched.isEmpty) await _stop();
    } on Object catch (error) {
      debugPrint('Temps réel : $error');
    }
  }

  @override
  void typing(String groupId) {
    final connection = _connection;
    if (connection?.state != HubConnectionState.Connected) return;
    unawaited(
      connection!
          .invoke('Typing', args: [groupId])
          .then<void>((_) {}, onError: (_) {}),
    );
  }

  @override
  Future<void> dispose() async {
    _watched.clear();
    await _stop();
    await _events.close();
    _connected.dispose();
  }

  Future<void> _ensureStarted() {
    if (_connection?.state == HubConnectionState.Connected) {
      return Future.value();
    }
    return _starting ??= _start().whenComplete(() => _starting = null);
  }

  Future<void> _start() async {
    final connection = HubConnectionBuilder()
        .withUrl(
          _hubUrl,
          options: HttpConnectionOptions(
            accessTokenFactory: () async => await _accessToken() ?? '',
          ),
        )
        .withAutomaticReconnect(
          retryDelays: const [0, 2000, 5000, 10000, 30000],
        )
        .build();

    connection.on('message', (args) {
      final json = _map(args, 0);
      if (json != null) {
        _events.add(GroupMessageEvent(GroupMessage.fromJson(json)));
      }
    });
    connection.on('messageDeleted', (args) {
      final groupId = _string(args, 0);
      final messageId = _string(args, 1);
      if (groupId != null && messageId != null) {
        _events.add(GroupMessageDeletedEvent(groupId, messageId));
      }
    });
    connection.on('changed', (args) {
      final groupId = _string(args, 0);
      final area = _string(args, 1);
      if (groupId != null && area != null) {
        _events.add(GroupChangedEvent(groupId, area));
      }
    });
    connection.on('read', (args) {
      final groupId = _string(args, 0);
      final userId = _string(args, 1);
      final readAt = _string(args, 2);
      if (groupId != null && userId != null && readAt != null) {
        _events.add(
          GroupReadEvent(groupId, userId, DateTime.parse(readAt).toLocal()),
        );
      }
    });
    connection.on('typing', (args) {
      final groupId = _string(args, 0);
      final userId = _string(args, 1);
      if (groupId != null && userId != null) {
        _events.add(GroupTypingEvent(groupId, userId));
      }
    });
    connection.onclose(({error}) => _connected.value = false);
    connection.onreconnecting(({error}) => _connected.value = false);
    connection.onreconnected(({connectionId}) async {
      _connected.value = true;
      // Après une coupure, le serveur a oublié les groupes suivis.
      for (final groupId in _watched.toList()) {
        await _join(groupId);
        _events.add(GroupChangedEvent(groupId, 'reconnected'));
      }
    });

    _connection = connection;
    await connection.start();
    _connected.value = true;
  }

  Future<void> _join(String groupId) async {
    final connection = _connection;
    if (connection?.state != HubConnectionState.Connected) return;
    try {
      await connection!.invoke('Join', args: [groupId]);
    } on Object catch (error) {
      debugPrint('Temps réel : impossible de suivre le groupe ($error)');
    }
  }

  Future<void> _stop() async {
    final connection = _connection;
    _connection = null;
    _connected.value = false;
    if (connection == null) return;
    try {
      await connection.stop();
    } on Object {
      // Déjà coupée.
    }
  }

  static Map<String, Object?>? _map(List<Object?>? args, int index) {
    final value = args != null && args.length > index ? args[index] : null;
    return value is Map ? Map<String, Object?>.from(value) : null;
  }

  static String? _string(List<Object?>? args, int index) {
    final value = args != null && args.length > index ? args[index] : null;
    return value?.toString();
  }
}
