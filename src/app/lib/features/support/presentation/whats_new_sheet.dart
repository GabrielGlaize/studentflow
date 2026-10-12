import 'package:flutter/material.dart';
import 'package:studyflow_app/core/release_notes.dart';
import 'package:studyflow_app/core/theme/app_colors.dart';
import 'package:studyflow_app/core/theme/prototype_widgets.dart';
import 'package:studyflow_app/core/widgets/swikko_logo.dart';

/// « Quoi de neuf » : les nouveautés de la version installée.
class WhatsNewSheet extends StatelessWidget {
  const WhatsNewSheet({required this.release, super.key});

  final AppRelease release;

  static Future<void> show(BuildContext context, {AppRelease? release}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (context) =>
          WhatsNewSheet(release: release ?? ReleaseNotes.current),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
        child: Column(
          key: const ValueKey('whats-new-sheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SwikkoLogo(size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ProtoOverline(
                        'Quoi de neuf · version ${release.version}',
                        color: context.sfAccent,
                      ),
                      Text(
                        release.title,
                        style: TextStyle(
                          color: context.sfText,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            ReleaseNotesList(release: release),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const ValueKey('whats-new-close'),
                onPressed: () => Navigator.pop(context),
                child: const Text('Super, on y va'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Nouveautés puis correctifs d'une version (Quoi de neuf, historique).
class ReleaseNotesList extends StatelessWidget {
  const ReleaseNotesList({required this.release, super.key});

  final AppRelease release;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in release.items)
          _Line(icon: Icons.auto_awesome, color: context.sfAccent, text: item),
        if (release.fixes.isNotEmpty) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ProtoOverline('Correctifs', color: context.sfMuted),
          ),
          for (final fix in release.fixes)
            _Line(
              icon: Icons.build_circle_outlined,
              color: context.sfMuted,
              text: fix,
            ),
        ],
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: context.sfText,
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
