import 'package:flutter/material.dart';
import 'package:studyflow_app/core/release_notes.dart';
import 'package:studyflow_app/core/theme/app_colors.dart';
import 'package:studyflow_app/core/theme/prototype_widgets.dart';
import 'package:studyflow_app/features/support/presentation/whats_new_sheet.dart';

/// Toutes les versions de Swikko, de la plus récente à la première.
class ReleaseHistoryPage extends StatelessWidget {
  const ReleaseHistoryPage({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (context) => const ReleaseHistoryPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historique des mises à jour')),
      body: ListView(
        key: const ValueKey('release-history-list'),
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 32),
        children: [
          for (final (index, release) in ReleaseNotes.releases.indexed)
            _ReleaseCard(release: release, isCurrent: index == 0),
        ],
      ),
    );
  }
}

class _ReleaseCard extends StatelessWidget {
  const _ReleaseCard({required this.release, required this.isCurrent});

  final AppRelease release;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    return ProtoCard(
      key: ValueKey('release-${release.version}'),
      borderColor: isCurrent ? context.sfAccent : AppColors.line,
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: isCurrent,
          tilePadding: const EdgeInsets.fromLTRB(16, 4, 12, 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
          title: Text(
            release.title,
            style: TextStyle(
              color: context.sfText,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          subtitle: Text(
            [
              'Version ${release.version}',
              release.date,
              if (isCurrent) 'installée',
            ].join(' · '),
            style: TextStyle(color: context.sfMuted, fontSize: 12),
          ),
          children: [ReleaseNotesList(release: release)],
        ),
      ),
    );
  }
}
