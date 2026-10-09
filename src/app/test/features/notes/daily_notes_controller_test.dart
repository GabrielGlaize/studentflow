import 'package:flutter_test/flutter_test.dart';
import 'package:studyflow_app/features/notes/application/daily_notes_controller.dart';
import 'package:studyflow_app/features/notes/data/daily_note_repository.dart';
import 'package:studyflow_app/features/notes/domain/daily_note.dart';
import 'package:studyflow_app/features/notifications/domain/notification_models.dart';

void main() {
  final morning = DateTime(2026, 10, 9, 10, 30);
  final evening = DateTime(2026, 10, 9, 20, 15);

  test('une note par jour, gardée et rechargée', () async {
    final storage = MemoryDailyNotesStorage();
    final controller = DailyNotesController(storage: storage)
      ..save(morning, 'Penser au badge\nAppeler la tutrice')
      ..save(DateTime(2026, 10, 8, 18), 'Hier');

    final reopened = DailyNotesController(storage: storage);
    await reopened.restore();

    expect(reopened.noteFor(evening)?.preview, 'Penser au badge');
    expect(reopened.history.map((note) => note.day.day), [9, 8]);
    expect(controller.history, hasLength(2));
  });

  test('une note vidée disparaît de l’historique', () {
    final controller = DailyNotesController(storage: MemoryDailyNotesStorage())
      ..save(morning, 'Brouillon')
      ..save(morning, '   ');

    expect(controller.noteFor(morning), isNull);
    expect(controller.history, isEmpty);
  });

  test('la saisie rapide ajoute une ligne horodatée', () {
    final controller = DailyNotesController(storage: MemoryDailyNotesStorage())
      ..append('Rendre le badge', at: DateTime(2026, 10, 9, 9, 5))
      ..append('  ', at: DateTime(2026, 10, 9, 9, 6))
      ..append('Acheter des intercalaires', at: DateTime(2026, 10, 9, 14, 2));

    expect(
      controller.noteFor(morning)?.text,
      '09:05 · Rendre le badge\n14:02 · Acheter des intercalaires',
    );
  });

  test('le soir, la note non relue est mise en avant jusqu’à sa lecture', () {
    final controller = DailyNotesController(storage: MemoryDailyNotesStorage())
      ..save(morning, 'Penser au badge');

    expect(controller.needsReview(morning), isFalse);
    expect(controller.needsReview(evening), isTrue);

    // Heure réglée plus tard : pas encore le moment.
    controller.reviewMinutes = 21 * 60;
    expect(controller.needsReview(evening), isFalse);
    controller.reviewMinutes = DailyNotesController.defaultReviewMinutes;

    controller.markReviewed(evening, now: evening);
    expect(controller.needsReview(evening), isFalse);
  });

  test('le rappel du soir suit l’heure réglée', () {
    final controller = DailyNotesController(storage: MemoryDailyNotesStorage());
    expect(controller.eveningReminder(morning), isNull);

    controller
      ..save(morning, 'Penser au badge')
      ..reviewMinutes = 18 * 60 + 30;
    final reminder = controller.eveningReminder(morning);
    expect(reminder?.type, ReminderType.note);
    expect(reminder?.scheduledAt, DateTime(2026, 10, 9, 18, 30));
    expect(reminder?.body, 'Penser au badge');

    // Passé l'heure du rappel, ou une fois relue : plus rien à programmer.
    expect(controller.eveningReminder(evening), isNull);
    controller.markReviewed(morning, now: morning);
    expect(controller.eveningReminder(morning), isNull);
  });

  group('synchronisation', () {
    test(
      'les notes partent au serveur et reviennent sur un autre appareil',
      () async {
        final server = _FakeServer();
        final phone = _controller(server);
        await phone.attachUser('user-1');

        phone.append('Rendre le badge', at: DateTime(2026, 10, 9, 9, 5));
        expect(phone.noteFor(morning)?.pendingSync, isTrue);
        await phone.sync();
        expect(phone.noteFor(morning)?.pendingSync, isFalse);
        expect(server.notes.values.single.text, '09:05 · Rendre le badge');

        final tablet = _controller(server);
        await tablet.attachUser('user-1');
        expect(tablet.noteFor(morning)?.text, '09:05 · Rendre le badge');

        // Effacée sur la tablette : elle disparaît aussi du téléphone.
        tablet.save(morning, '');
        await tablet.sync();
        await phone.sync();
        expect(server.notes, isEmpty);
        expect(phone.noteFor(morning), isNull);
      },
    );

    test(
      'hors connexion, la note attend puis part au retour du réseau',
      () async {
        final server = _FakeServer();
        final phone = _controller(server);
        await phone.attachUser('user-1');

        server.offline = true;
        phone.save(morning, 'Écrit dans le métro');
        await phone.sync();
        expect(phone.noteFor(morning)?.pendingSync, isTrue);
        expect(server.notes, isEmpty);

        server.offline = false;
        await phone.sync();
        expect(server.notes.values.single.text, 'Écrit dans le métro');
      },
    );

    test('un autre compte ne retrouve pas le carnet précédent', () async {
      final storage = MemoryDailyNotesStorage();
      final server = _FakeServer();
      final phone = _controller(server, storage: storage);
      await phone.attachUser('user-1');
      phone.save(morning, 'Note perso');
      await phone.sync();

      await phone.attachUser(null);
      expect(phone.history, isEmpty);
      expect((await storage.read()).notes, isEmpty);
    });
  });
}

DailyNotesController _controller(
  _FakeServer server, {
  DailyNotesStorage? storage,
}) {
  return DailyNotesController(
    storage: storage ?? MemoryDailyNotesStorage(),
    repository: server,
    accessToken: () async => 'token',
    pushDelay: const Duration(days: 1),
  );
}

/// Serveur en mémoire : la version la plus récente l'emporte, comme l'API.
class _FakeServer implements DailyNoteRepository {
  final Map<DateTime, DailyNote> notes = {};
  bool offline = false;

  @override
  Future<List<DailyNote>> listNotes({String? accessToken}) async {
    if (offline) throw Exception('Hors connexion');
    return notes.values.toList();
  }

  @override
  Future<DailyNote?> saveNote(DailyNote note, {String? accessToken}) async {
    if (offline) throw Exception('Hors connexion');
    final current = notes[note.day];
    if (current != null && current.updatedAt.isAfter(note.updatedAt)) {
      return current;
    }
    if (note.isEmpty) {
      notes.remove(note.day);
      return null;
    }
    return notes[note.day] = note.copyWith(pendingSync: false);
  }
}
