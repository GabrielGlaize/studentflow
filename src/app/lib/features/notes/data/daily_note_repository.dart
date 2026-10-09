import 'package:studyflow_app/core/network/api_client.dart';
import 'package:studyflow_app/features/notes/domain/daily_note.dart';

/// Notes du jour côté serveur (chiffrées en base, visibles par leur seul
/// auteur).
abstract interface class DailyNoteRepository {
  Future<List<DailyNote>> listNotes({String? accessToken});

  /// Enregistre la note, ou l'efface si elle est vide. Renvoie la version
  /// retenue par le serveur (la plus récente), `null` si la note est effacée.
  Future<DailyNote?> saveNote(DailyNote note, {String? accessToken});
}

class HttpDailyNoteRepository implements DailyNoteRepository {
  const HttpDailyNoteRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<List<DailyNote>> listNotes({String? accessToken}) async {
    final json = await _apiClient.getJsonList(
      '/api/v1/daily-notes',
      accessToken: accessToken,
    );
    return json.map(DailyNote.fromJson).toList(growable: false);
  }

  @override
  Future<DailyNote?> saveNote(DailyNote note, {String? accessToken}) async {
    final path = '/api/v1/daily-notes/${note.dayKey}';
    if (note.isEmpty) {
      await _apiClient.deleteNoContent(path, accessToken: accessToken);
      return null;
    }

    final json = await _apiClient.putJson(
      path,
      body: note.toApiJson(),
      accessToken: accessToken,
    );
    return DailyNote.fromJson(json);
  }
}
