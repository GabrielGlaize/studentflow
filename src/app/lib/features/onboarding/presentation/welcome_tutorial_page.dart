import 'dart:async';

import 'package:flutter/material.dart';
import 'package:studyflow_app/core/app_scope.dart';
import 'package:studyflow_app/core/theme/app_colors.dart';
import 'package:studyflow_app/core/theme/prototype_widgets.dart';
import 'package:studyflow_app/features/profile/domain/app_preferences.dart';

/// Présentation de l'app, montrée une fois après la création du compte (et
/// rejouable depuis les paramètres). Une page par usage, trois lignes au
/// plus : on lit, on comprend, on passe. « Passer » est toujours visible.
class WelcomeTutorialPage extends StatefulWidget {
  const WelcomeTutorialPage({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (context) => const WelcomeTutorialPage(),
      ),
    );
  }

  @override
  State<WelcomeTutorialPage> createState() => _WelcomeTutorialPageState();
}

class _WelcomeTutorialPageState extends State<WelcomeTutorialPage> {
  static const _pageCount = 6;

  final _controller = PageController();
  int _page = 0;

  /// Choix fait sur la page entreprise (`null` : pas encore répondu).
  bool? _hasCompany;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _hasCompany ??= AppScope.of(context).settingsController.hasCompany
        ? true
        : null;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page == _pageCount - 1) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _finish() {
    AppScope.of(context).settingsController.completeTutorial();
    Navigator.of(context).pop();
  }

  /// « J'ai une entreprise » transforme l'onglet Alternance en Entreprise.
  void _chooseCompany(bool value) {
    setState(() => _hasCompany = value);
    final appScope = AppScope.of(context);
    final settings = appScope.settingsController..setHasCompany(value);
    unawaited(() async {
      try {
        final accessToken = await appScope.sessionController
            .accessTokenForApi();
        await appScope.appPreferencesRepository.updatePreferences(
          preferences: RemoteAppPreferences(
            themeMode: settings.themeMode,
            hasCompany: value,
            companyName: settings.companyName,
            professionalMode: value
                ? ProfessionalMode.company
                : ProfessionalMode.apprenticeship,
          ),
          accessToken: accessToken,
        );
      } on Exception {
        // Réglage local déjà enregistré ; la synchronisation se refera.
      }
    }());
  }

  @override
  Widget build(BuildContext context) {
    final user = AppScope.of(context).sessionController.session?.user;
    final firstName = user?.firstName.trim() ?? '';
    final pages = [
      _WelcomePage(firstName: firstName),
      _ClassPage(
        hasClass: user?.schoolClassId != null,
        isDelegate: user?.isDelegate == true,
      ),
      const _GroupPage(),
      const _PersonalPage(),
      _CompanyPage(hasCompany: _hasCompany, onChoose: _chooseCompany),
      const _ReadyPage(),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
              child: Row(
                children: [
                  for (var i = 0; i < _pageCount; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 6),
                      width: i == _page ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i <= _page ? context.sfAccent : context.sfLine,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  const Spacer(),
                  if (_page < _pageCount - 1)
                    TextButton(
                      key: const ValueKey('tutorial-skip'),
                      onPressed: _finish,
                      child: const Text('Passer'),
                    ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                key: const ValueKey('tutorial-pager'),
                controller: _controller,
                onPageChanged: (page) => setState(() => _page = page),
                children: [
                  for (final page in pages)
                    SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
                      child: page,
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey('tutorial-next'),
                  onPressed: _next,
                  child: Text(
                    _page == _pageCount - 1 ? 'C’est parti' : 'Suivant',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// En-tête commun : grande icône, sur-titre, titre, phrase d'accroche.
class _Header extends StatelessWidget {
  const _Header({
    required this.icon,
    required this.overline,
    required this.title,
    required this.lead,
    this.color,
  });

  final IconData icon;
  final String overline;
  final String title;
  final String lead;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? context.sfAccent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(icon, size: 32, color: accent),
        ),
        const SizedBox(height: 18),
        ProtoOverline(overline, color: accent),
        const SizedBox(height: 4),
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: context.sfText,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          lead,
          style: TextStyle(color: context.sfMuted, fontSize: 15, height: 1.4),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

/// Une fonctionnalité : icône, quoi, où la trouver.
class _Feature extends StatelessWidget {
  const _Feature({
    required this.icon,
    required this.title,
    required this.text,
    this.color,
  });

  final IconData icon;
  final String title;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? context.sfIcon;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: context.sfCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.sfLine),
            ),
            child: Icon(icon, size: 20, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: context.sfText,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: TextStyle(
                    color: context.sfMuted,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Encadré « à savoir » (pas de classe, rôle de délégué…).
class _Callout extends StatelessWidget {
  const _Callout({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final accent = context.sfShared;

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: context.sfText,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage({required this.firstName});

  final String firstName;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(
          icon: Icons.waving_hand_outlined,
          overline: 'Bienvenue',
          title: firstName.isEmpty
              ? 'Swikko en 30 secondes'
              : 'Salut $firstName, voici Swikko',
          lead:
              'Ton année au même endroit : cours, devoirs, organisation '
              'perso et alternance.',
        ),
        const _Feature(
          icon: Icons.home_outlined,
          title: 'Accueil',
          text:
              'L’essentiel du jour : prochain cours, infos de la classe, '
              'ce qui est à rendre.',
        ),
        const _Feature(
          icon: Icons.calendar_month_outlined,
          title: 'Planning et Agenda',
          text: 'Les cours d’un côté, les devoirs et tes tâches de l’autre.',
        ),
        const SizedBox(height: 6),
        Text(
          'Deux couleurs à retenir',
          style: TextStyle(
            color: context.sfText,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        const Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ProtoVisibilityChip(shared: true),
            ProtoVisibilityChip(shared: false),
          ],
        ),
        const SizedBox(height: 8),
        const ProtoMutedText(
          'Bleu : partagé avec toute la classe. Vert : visible par toi seul.',
        ),
      ],
    );
  }
}

class _ClassPage extends StatelessWidget {
  const _ClassPage({required this.hasClass, required this.isDelegate});

  final bool hasClass;
  final bool isDelegate;

  @override
  Widget build(BuildContext context) {
    final shared = context.sfShared;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(
          icon: Icons.groups_outlined,
          overline: 'Avec ta classe',
          title: 'On s’organise ensemble',
          lead:
              'Tout le monde peut compléter : un cours oublié, un devoir '
              'donné à l’oral… La classe en profite.',
          color: shared,
        ),
        _Feature(
          icon: Icons.calendar_today_outlined,
          title: 'Planning partagé',
          text:
              'Ajoute ou corrige un cours. Prof absent ? Les trois petits '
              'points, puis « Annuler le cours », et le reste de la journée suit.',
          color: shared,
        ),
        _Feature(
          icon: Icons.assignment_outlined,
          title: 'Devoirs et évaluations',
          text:
              'Un devoir ajouté apparaît chez tous. Les évaluations '
              'ressortent en ambre.',
          color: shared,
        ),
        _Feature(
          icon: Icons.campaign_outlined,
          title: 'Infos classe et partiels',
          text:
              'Le fil officiel du délégué, et une fiche de révision '
              'commune avant les partiels.',
          color: shared,
        ),
        if (!hasClass)
          const _Callout(
            icon: Icons.key_outlined,
            text:
                'Pas encore de classe ? Demande le code à ton délégué et '
                'rejoins-la depuis Profil. Tu peux aussi créer la tienne.',
          )
        else if (isDelegate)
          const _Callout(
            icon: Icons.verified_user_outlined,
            text:
                'Tu es délégué : partage le code de la classe et valide '
                'les demandes depuis Profil › Gérer la classe.',
          ),
      ],
    );
  }
}

class _GroupPage extends StatelessWidget {
  const _GroupPage();

  @override
  Widget build(BuildContext context) {
    final group = context.sfGroup;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(
          icon: Icons.diversity_3_outlined,
          overline: 'Travail de groupe',
          title: 'Un projet à plusieurs',
          lead:
              'Crée un groupe privé avec quelques camarades, lié à un devoir '
              'ou à un cours. Seuls ses membres le voient.',
          color: group,
        ),
        _Feature(
          icon: Icons.forum_outlined,
          title: 'Discussion en direct',
          text:
              'Les messages arrivent à l’instant, avec « … écrit » et « vu ».',
          color: group,
        ),
        _Feature(
          icon: Icons.checklist_outlined,
          title: 'Tâches réparties',
          text:
              'Chacun sait quoi faire et pour quand ; tes tâches arrivent '
              'dans ton agenda.',
          color: group,
        ),
        _Feature(
          icon: Icons.event_available_outlined,
          title: 'Créneaux communs',
          text:
              'Swikko croise le planning et les jours en entreprise pour '
              'trouver quand tout le monde est libre.',
          color: group,
        ),
      ],
    );
  }
}

class _PersonalPage extends StatelessWidget {
  const _PersonalPage();

  @override
  Widget build(BuildContext context) {
    final personal = context.sfPersonal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(
          icon: Icons.lock_outline,
          overline: 'Pour toi seul',
          title: 'Ton organisation perso',
          lead:
              'Ce que tu ajoutes ici reste privé, même si tu es dans une '
              'classe.',
          color: personal,
        ),
        _Feature(
          icon: Icons.checklist_outlined,
          title: 'Tâches et événements',
          text:
              'Dans Agenda : « Liste » par espace, ou « Calendrier » pour '
              'voir la semaine ou le mois d’un coup.',
          color: personal,
        ),
        _Feature(
          icon: Icons.edit_note,
          title: 'Note rapide',
          text:
              '« Oh c’est vrai… » : le crayon de l’accueil, une ligne, '
              'c’est noté. Rappel le soir pour relire.',
          color: personal,
        ),
        _Feature(
          icon: Icons.notifications_paused_outlined,
          title: 'Rappels, à ta façon',
          text:
              'Choisis quand être prévenu, et coupe tout la nuit avec '
              '« Ne pas déranger ».',
          color: personal,
        ),
      ],
    );
  }
}

class _CompanyPage extends StatelessWidget {
  const _CompanyPage({required this.hasCompany, required this.onChoose});

  final bool? hasCompany;
  final ValueChanged<bool> onChoose;

  @override
  Widget build(BuildContext context) {
    final green = context.sfPersonal;
    final hasCompany = this.hasCompany;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(
          icon: Icons.work_outline,
          overline: 'Alternance',
          title: 'Tu as déjà une entreprise ?',
          lead:
              'L’onglet s’adapte. Tu pourras changer d’avis dans '
              'Paramètres, et tu peux passer cette étape.',
          color: green,
        ),
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                key: const ValueKey('tutorial-has-company'),
                label: const Text('Oui, j’en ai une'),
                selected: hasCompany == true,
                onSelected: (_) => onChoose(true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ChoiceChip(
                key: const ValueKey('tutorial-no-company'),
                label: const Text('Je cherche encore'),
                selected: hasCompany == false,
                onSelected: (_) => onChoose(false),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (hasCompany == true) ...[
          _Feature(
            icon: Icons.folder_outlined,
            title: 'Documents importants',
            text: 'Contrat, convention, fiches de paie… et tes propres types.',
            color: green,
          ),
          _Feature(
            icon: Icons.contacts_outlined,
            title: 'Contacts',
            text: 'Ton tuteur et les personnes utiles, à un appui.',
            color: green,
          ),
          _Feature(
            icon: Icons.task_alt_outlined,
            title: 'Tâches entreprise',
            text: 'À part de l’école, dans l’espace Entreprise de l’agenda.',
            color: green,
          ),
        ] else if (hasCompany == false) ...[
          _Feature(
            icon: Icons.search,
            title: 'Recherche d’offres',
            text: 'Des offres d’alternance filtrées, même sans compte.',
            color: green,
          ),
          _Feature(
            icon: Icons.bookmark_outline,
            title: 'Favoris et recherches',
            text:
                'Garde les offres qui t’intéressent et relance tes recherches.',
            color: green,
          ),
          _Feature(
            icon: Icons.forum_outlined,
            title: 'Entraide de la classe',
            text: 'Les offres et contacts partagés par les autres élèves.',
            color: green,
          ),
        ] else
          const ProtoMutedText(
            'Pas d’entreprise pour l’instant ? Aucun souci : passe, '
            'l’espace Alternance t’aidera à en trouver une.',
          ),
      ],
    );
  }
}

class _ReadyPage extends StatelessWidget {
  const _ReadyPage();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(
          icon: Icons.rocket_launch_outlined,
          overline: 'C’est prêt',
          title: 'Trois gestes à connaître',
          lead: 'Le reste se découvre en route.',
        ),
        _Feature(
          icon: Icons.swipe_outlined,
          title: 'Balaie',
          text:
              'D’un jour à l’autre dans le Planning, d’un espace à '
              'l’autre dans l’Agenda.',
        ),
        _Feature(
          icon: Icons.more_horiz,
          title: 'Les trois petits points',
          text:
              'Sur un cours ou un devoir : modifier, annuler, ajouter un devoir…',
        ),
        _Feature(
          icon: Icons.settings_outlined,
          title: 'Revoir cette présentation',
          text: 'Profil › Paramètres › Revoir la présentation.',
        ),
      ],
    );
  }
}
