import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:studyflow_app/features/notes/data/daily_note_repository.dart';
import 'package:studyflow_app/features/notes/domain/daily_note.dart';
import 'package:studyflow_app/features/notifications/domain/notification_models.dart';

/// Coin note : une note par jour, synchronisée entre les appareils de l'élève.
///
/// On écrit d'abord sur le téléphone (ça marche hors connexion), puis les
/// modifications partent au serveur, qui les garde chiffrées. Le soir,
/// l'accueil met la note en avant et une notification la rappelle, tant
/// qu'elle n'a pas été rouverte.
class DailyNotesController extends ChangeNotifier {
  DailyNotesController({
    required DailyNotesStorage storage,
    DailyNoteRepository? repository,
    Future<String?> Function()? accessToken,
    this.pushDelay = const Duration(seconds: 2),
  }) : _storage = storage,
       _repository = repository,
       _accessToken = accessToken;

  /// Rappel du soir par défaut : 19 h.
  static const defaultReviewMinutes = 19 * 60;

  final DailyNotesStorage _storage;

  /// Absent en mode démo : le carnet reste alors sur le téléphone.
  final DailyNoteRepository? _repository;
  final Future<String?> Function()? _accessToken;

  /// Délai avant l'envoi : on n'envoie pas chaque lettre tapée.
  final Duration pushDelay;

  final Map<DateTime, DailyNote> _notes = {};

  /// Compte à qui appartient le carnet gardé sur ce téléphone.
  String? _ownerId;
  Future<void>? _restoring;
  Timer? _pushTimer;
  bool _syncing = false;
  bool _syncAgain = false;
  int _reviewMinutes = defaultReviewMinutes;

  /// Heure du rappel du soir, en minutes depuis minuit (réglable).
  int get reviewMinutes => _reviewMinutes;

  set reviewMinutes(int value) {
    if (_reviewMinutes == value) return;
    _reviewMinutes = value;
    notifyListeners();
  }

  Future<void> restore() => _restoring ??= _restore();

  Future<void> _restore() async {
    try {
      final saved = await _storage.read();
      _ownerId = saved.ownerId;
      _notes
        ..clear()
        ..addEntries(saved.notes.map((note) => MapEntry(note.day, note)));
      notifyListeners();
    } on Exception {
      // Fichier illisible : on repart d'un carnet vide plutôt que de bloquer.
    }
  }

  /// Rattache le carnet au compte connecté (`null` à la déconnexion). Les
  /// notes d'un autre compte ne restent pas sur le téléphone.
  Future<void> attachUser(String? userId) async {
    await restore();
    if (userId == _ownerId) {
      if (userId != null) await sync();
      return;
    }

    if (_ownerId == null && userId != null) {
      // Notes écrites avant la synchronisation : elles rejoignent ce compte.
      for (final note in _notes.values.toList()) {
        _notes[note.day] = note.copyWith(pendingSync: true);
      }
    } else {
      _notes.clear();
    }
    _ownerId = userId;
    _persist();
    notifyListeners();
    if (userId != null) await sync();
  }

  /// Les notes partent au serveur (faux en mode démo : tout reste ici).
  bool get syncsWithServer => _repository != null && _ownerId != null;

  DailyNote? noteFor(DateTime day) => _notes[DailyNote.dayOf(day)];

  /// Notes écrites, de la plus récente à la plus ancienne.
  List<DailyNote> get history =>
      _notes.values.where((note) => !note.isEmpty).toList()
        ..sort((a, b) => b.day.compareTo(a.day));

  void save(DateTime day, String text) {
    final key = DailyNote.dayOf(day);
    final previous = _notes[key];
    if ((previous?.text ?? '') == text) return;

    if (text.trim().isEmpty && (previous == null || _repository == null)) {
      // Rien à effacer côté serveur.
      _notes.remove(key);
    } else {
      _notes[key] = DailyNote(
        day: key,
        text: text,
        updatedAt: DateTime.now(),
        reviewedAt: previous?.reviewedAt,
        pendingSync: true,
      );
    }
    _changed();
  }

  /// Saisie rapide (« oh c'est vrai… ») : ajoute une ligne horodatée à la
  /// note du jour, sans ouvrir l'éditeur.
  void append(String line, {DateTime? at}) {
    final cleaned = line.trim();
    if (cleaned.isEmpty) return;

    final moment = at ?? DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    final entry = '${two(moment.hour)}:${two(moment.minute)} · $cleaned';
    final current = noteFor(moment)?.text.trimRight() ?? '';
    save(moment, current.isEmpty ? entry : '$current\n$entry');
  }

  /// La note a été relue (ouverte le soir) : plus de mise en avant, sur
  /// aucun appareil.
  void markReviewed(DateTime day, {DateTime? now}) {
    final note = noteFor(day);
    if (note == null || note.isEmpty || note.reviewedAt != null) return;

    final moment = now ?? DateTime.now();
    _notes[note.day] = note.copyWith(
      reviewedAt: moment,
      updatedAt: moment,
      pendingSync: true,
    );
    _changed();
  }

  /// Le soir venu, la note du jour n'a pas encore été relue.
  bool needsReview(DateTime now) {
    final note = noteFor(now);
    return note != null &&
        !note.isEmpty &&
        note.reviewedAt == null &&
        now.hour * 60 + now.minute >= _reviewMinutes;
  }

  /// Rappel du soir à programmer sur le téléphone, s'il y a de quoi relire.
  ScheduledReminder? eveningReminder(DateTime now) {
    final note = noteFor(now);
    if (note == null || note.isEmpty || note.reviewedAt != null) return null;

    final at = DateTime(
      now.year,
      now.month,
      now.day,
      _reviewMinutes ~/ 60,
      _reviewMinutes % 60,
    );
    if (!at.isAfter(now)) return null;

    return ScheduledReminder(
      id: 'daily-note-${note.dayKey}',
      type: ReminderType.note,
      title: 'Ta note du jour',
      body: note.preview,
      scheduledAt: at,
      sourceId: note.dayKey,
    );
  }

  /// Envoie les modifications en attente puis récupère celles des autres
  /// appareils. Hors connexion, tout reste sur le téléphone et repartira au
  /// prochain essai (ouverture de l'app, nouvelle modification…).
  Future<void> sync() async {
    final repository = _repository;
    final owner = _ownerId;
    if (repository == null || owner == null) return;
    if (_syncing) {
      _syncAgain = true;
      return;
    }

    _syncing = true;
    _pushTimer?.cancel();
    try {
      do {
        _syncAgain = false;
        final accessToken = await _accessToken?.call();

        for (final note in _notes.values.where((x) => x.pendingSync).toList()) {
          final saved = await repository.saveNote(
            note,
            accessToken: accessToken,
          );
          if (_ownerId != owner) return;
          // Retouchée pendant l'envoi : la nouvelle version partira au tour
          // suivant.
          if (!identical(_notes[note.day], note)) continue;
          if (saved == null) {
            _notes.remove(note.day);
          } else {
            _notes[note.day] = saved;
          }
        }

        final remote = await repository.listNotes(accessToken: accessToken);
        if (_ownerId != owner) return;
        final remoteDays = {for (final note in remote) note.day: note};
        // Effacée depuis un autre appareil.
        _notes.removeWhere(
          (day, note) => !note.pendingSync && !remoteDays.containsKey(day),
        );
        for (final note in remote) {
          final local = _notes[note.day];
          if (local == null || !local.pendingSync) _notes[note.day] = note;
        }
        _persist();
        notifyListeners();
      } while (_syncAgain);
    } on Exception {
      // Hors connexion ou session expirée : nouvel essai plus tard.
    } finally {
      _syncing = false;
    }
  }

  void _changed() {
    _persist();
    notifyListeners();
    if (_repository == null || _ownerId == null) return;
    _pushTimer?.cancel();
    _pushTimer = Timer(pushDelay, () => unawaited(sync()));
  }

  void _persist() {
    unawaited(
      _storage.save(
        DailyNotesSnapshot(ownerId: _ownerId, notes: _notes.values.toList()),
      ),
    );
  }

  @override
  void dispose() {
    _pushTimer?.cancel();
    super.dispose();
  }
}

/// Ce que le téléphone garde : les notes et le compte à qui elles sont.
class DailyNotesSnapshot {
  const DailyNotesSnapshot({required this.ownerId, required this.notes});

  static const empty = DailyNotesSnapshot(ownerId: null, notes: []);

  final String? ownerId;
  final List<DailyNote> notes;

  factory DailyNotesSnapshot.fromJson(Object? json) {
    // Premier format : une simple liste de notes, sans compte.
    if (json is List) {
      return DailyNotesSnapshot(ownerId: null, notes: _notesFrom(json));
    }
    if (json is! Map<String, Object?>) return empty;
    return DailyNotesSnapshot(
      ownerId: json['ownerId'] as String?,
      notes: _notesFrom(json['notes']),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'ownerId': ownerId,
      'notes': notes.map((note) => note.toJson()).toList(),
    };
  }

  static List<DailyNote> _notesFrom(Object? json) {
    if (json is! List) return const [];
    return json
        .whereType<Map<String, Object?>>()
        .map(DailyNote.fromJson)
        .toList(growable: false);
  }
}

abstract interface class DailyNotesStorage {
  Future<DailyNotesSnapshot> read();

  Future<void> save(DailyNotesSnapshot snapshot);
}

/// Un fichier JSON dans le dossier privé de l'app.
class FileDailyNotesStorage implements DailyNotesStorage {
  static const _fileName = 'daily_notes.json';

  Future<File> _file() async {
    final directory = await getApplicationSupportDirectory();
    return File('${directory.path}/$_fileName');
  }

  @override
  Future<DailyNotesSnapshot> read() async {
    final file = await _file();
    if (!await file.exists()) return DailyNotesSnapshot.empty;
    return DailyNotesSnapshot.fromJson(jsonDecode(await file.readAsString()));
  }

  /// Les écritures passent une par une : deux enregistrements rapprochés ne
  /// se marchent pas dessus sur le fichier temporaire.
  Future<void> _pending = Future.value();

  @override
  Future<void> save(DailyNotesSnapshot snapshot) {
    return _pending = _pending.then((_) => _write(snapshot)).catchError((
      Object error,
    ) {
      debugPrint('Notes du jour non enregistrées : $error');
    });
  }

  Future<void> _write(DailyNotesSnapshot snapshot) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    // Écriture dans un fichier temporaire puis renommage : pas de carnet
    // à moitié écrit si l'app est coupée pendant l'enregistrement.
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(jsonEncode(snapshot.toJson()), flush: true);
    await temporary.rename(file.path);
  }
}

class MemoryDailyNotesStorage implements DailyNotesStorage {
  DailyNotesSnapshot _snapshot = DailyNotesSnapshot.empty;

  @override
  Future<DailyNotesSnapshot> read() async => _snapshot;

  @override
  Future<void> save(DailyNotesSnapshot snapshot) async {
    _snapshot = DailyNotesSnapshot(
      ownerId: snapshot.ownerId,
      notes: List.of(snapshot.notes),
    );
  }
}
