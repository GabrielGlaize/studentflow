import 'package:flutter/material.dart';
import 'package:studyflow_app/core/app_scope.dart';
import 'package:studyflow_app/core/theme/app_colors.dart';
import 'package:studyflow_app/core/theme/prototype_widgets.dart';
import 'package:studyflow_app/features/notes/presentation/daily_note_page.dart';
import 'package:studyflow_app/features/notes/presentation/numbered_text_editor.dart';

/// Saisie éclair : « oh c'est vrai… ». Le clavier s'ouvre tout de suite, une
/// ligne, Entrée, c'est noté dans la note du jour (avec l'heure) et la feuille
/// se referme. La note complète et l'historique restent à un geste.
class QuickNoteSheet extends StatefulWidget {
  const QuickNoteSheet({super.key});

  static Future<void> show(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (context) => const QuickNoteSheet(),
    );
    if (added != true || !context.mounted) return;

    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: const Text('Noté dans ta note du jour.'),
          action: SnackBarAction(
            label: 'Voir',
            onPressed: () {
              if (context.mounted) DailyNotePage.open(context);
            },
          ),
        ),
      );
  }

  @override
  State<QuickNoteSheet> createState() => _QuickNoteSheetState();
}

class _QuickNoteSheetState extends State<QuickNoteSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      Navigator.pop(context);
      return;
    }

    final appScope = AppScope.of(context);
    final notes = appScope.dailyNotesController;
    final hadNote = notes.noteFor(DateTime.now())?.isEmpty == false;
    notes.append(text);
    // Première ligne du jour : le rappel du soir devient utile.
    if (!hadNote) appScope.reminderSync.requestSync();
    Navigator.pop(context, true);
  }

  void _openFullNote() {
    // La feuille se ferme : on garde le navigateur pour ouvrir la note.
    final navigator = Navigator.of(context)..pop();
    navigator.push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (context) => const DailyNotePage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = AppScope.of(
      context,
    ).dailyNotesController.noteFor(DateTime.now());
    // Lignes numérotées comme dans l'éditeur (lignes vides comprises).
    final lines = (today?.text ?? '').trimRight().split('\n');
    final lineCount = today == null || today.isEmpty ? 0 : lines.length;
    final previous = [
      for (final (index, line) in lines.indexed)
        if (line.trim().isNotEmpty) (index + 1, line.trim()),
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(
        18,
        0,
        18,
        MediaQuery.viewInsetsOf(context).bottom + 18,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Note rapide',
                  style: TextStyle(
                    color: context.sfText,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              TextButton.icon(
                key: const ValueKey('quick-note-open-full'),
                onPressed: _openFullNote,
                icon: const Icon(Icons.open_in_full, size: 18),
                label: const Text('Note du jour'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('quick-note-field'),
            controller: _controller,
            autofocus: true,
            minLines: 1,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _add(),
            decoration: InputDecoration(
              hintText: 'Oh c’est vrai… rendre le badge',
              // Numéro de la ligne qui va s'ajouter, comme dans l'éditeur.
              prefixIcon: SizedBox(
                width: 44,
                child: Center(
                  child: Text(
                    '${lineCount + 1}',
                    key: const ValueKey('quick-note-next-line'),
                    style: lineNumberStyle(context, fontSize: 14),
                  ),
                ),
              ),
              suffixIcon: Padding(
                padding: const EdgeInsets.all(6),
                child: IconButton.filled(
                  key: const ValueKey('quick-note-send'),
                  tooltip: 'Noter',
                  onPressed: _add,
                  icon: const Icon(Icons.arrow_upward),
                ),
              ),
            ),
          ),
          if (previous.isNotEmpty) ...[
            const SizedBox(height: 12),
            ProtoMutedText(
              'Déjà noté aujourd’hui · $lineCount ligne${lineCount > 1 ? 's' : ''}',
            ),
            const SizedBox(height: 4),
            for (final (number, line)
                in previous.reversed.take(3).toList().reversed)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: Text(
                        '$number',
                        textAlign: TextAlign.end,
                        style: lineNumberStyle(context, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        line,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: context.sfMuted, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
