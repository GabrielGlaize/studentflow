import 'package:flutter/material.dart';
import 'package:studyflow_app/core/app_scope.dart';
import 'package:studyflow_app/core/release_notes.dart';
import 'package:studyflow_app/core/theme/app_colors.dart';
import 'package:studyflow_app/features/agenda/presentation/agenda_page.dart';
import 'package:studyflow_app/features/apprenticeships/presentation/apprenticeships_page.dart';
import 'package:studyflow_app/features/company/presentation/company_page.dart';
import 'package:studyflow_app/features/dashboard/presentation/dashboard_page.dart';
import 'package:studyflow_app/features/onboarding/presentation/welcome_tutorial_page.dart';
import 'package:studyflow_app/features/profile/presentation/profile_page.dart';
import 'package:studyflow_app/features/schedule/presentation/schedule_page.dart';
import 'package:studyflow_app/features/support/presentation/whats_new_sheet.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;
  String _agendaInitialCategory = 'school';
  bool _tutorialOpen = false;

  /// Compte tout juste créé : la présentation s'ouvre par-dessus l'accueil.
  void _showTutorialIfPending() {
    final settings = AppScope.of(context).settingsController;
    if (!settings.tutorialPending || _tutorialOpen) return;
    _tutorialOpen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // Le message « Compte créé » masquerait le bouton « Suivant ».
      ScaffoldMessenger.of(context).clearSnackBars();
      await WelcomeTutorialPage.open(context);
      // Fermée autrement (retour système) : on ne la remontre pas.
      if (mounted) AppScope.of(context).settingsController.completeTutorial();
      _tutorialOpen = false;
    });
  }

  bool _whatsNewOpen = false;

  /// Après une mise à jour : « Quoi de neuf », une seule fois par version.
  /// Première installation ou compte tout neuf : rien (la présentation suffit).
  void _showWhatsNewIfUpdated() {
    final settings = AppScope.of(context).settingsController;
    final current = ReleaseNotes.current.version;
    if (settings.lastSeenRelease == current || _whatsNewOpen) return;
    // Première installation : rien de « nouveau » à montrer.
    if (settings.lastSeenRelease == null ||
        settings.tutorialPending ||
        _tutorialOpen) {
      // Après l'image en cours : prévenir pendant le build est interdit.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => settings.markReleaseSeen(current),
      );
      return;
    }
    _whatsNewOpen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      AppScope.of(context).settingsController.markReleaseSeen(current);
      await WhatsNewSheet.show(context);
      _whatsNewOpen = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settingsController = AppScope.of(context).settingsController;

    return AnimatedBuilder(
      animation: settingsController,
      builder: (context, _) {
        _showTutorialIfPending();
        _showWhatsNewIfUpdated();
        return LayoutBuilder(
          builder: (context, constraints) {
            final useRail = constraints.maxWidth >= 840;
            final destinations = _buildDestinations(
              hasCompany: settingsController.hasCompany,
              companyName: settingsController.companyName,
            );

            if (useRail) {
              return Scaffold(
                body: Row(
                  children: [
                    NavigationRail(
                      selectedIndex: _selectedIndex,
                      onDestinationSelected: _selectPage,
                      labelType: NavigationRailLabelType.all,
                      destinations: destinations
                          .map(
                            (item) => NavigationRailDestination(
                              icon: item.icon,
                              selectedIcon: item.selectedIcon,
                              label: Text(item.label),
                            ),
                          )
                          .toList(),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: _pageForIndex(
                        _selectedIndex,
                        hasCompany: settingsController.hasCompany,
                      ),
                    ),
                  ],
                ),
              );
            }

            return Scaffold(
              body: _pageForIndex(
                _selectedIndex,
                hasCompany: settingsController.hasCompany,
              ),
              bottomNavigationBar: DecoratedBox(
                decoration: BoxDecoration(
                  color: context.sfCard,
                  border: Border(top: BorderSide(color: context.sfLine)),
                ),
                child: NavigationBar(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _selectPage,
                  destinations: destinations,
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _selectPage(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _pageForIndex(int index, {required bool hasCompany}) {
    switch (index) {
      case 0:
        return DashboardPage(
          onOpenSchedule: _openSchedule,
          onOpenAgenda: _openSchoolAgenda,
        );
      case 1:
        return const SchedulePage();
      case 2:
        return AgendaPage(initialCategory: _agendaInitialCategory);
      case 3:
        if (!hasCompany) return const ApprenticeshipsPage();
        return CompanyPage(onOpenCompanyTasks: _openCompanyTasks);
      default:
        return const ProfilePage();
    }
  }

  void _openCompanyTasks() {
    setState(() {
      _agendaInitialCategory = 'company';
      _selectedIndex = 2;
    });
  }

  void _openSchoolAgenda() {
    setState(() {
      _agendaInitialCategory = 'school';
      _selectedIndex = 2;
    });
  }

  void _openSchedule() {
    setState(() {
      _selectedIndex = 1;
    });
  }

  List<NavigationDestination> _buildDestinations({
    required bool hasCompany,
    required String? companyName,
  }) {
    return [
      const NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home),
        label: 'Accueil',
      ),
      const NavigationDestination(
        icon: Icon(Icons.calendar_month_outlined),
        selectedIcon: Icon(Icons.calendar_month),
        label: 'Planning',
      ),
      const NavigationDestination(
        icon: Icon(Icons.checklist_outlined),
        selectedIcon: Icon(Icons.checklist),
        label: 'Agenda',
      ),
      NavigationDestination(
        icon: const Icon(Icons.work_outline),
        selectedIcon: const Icon(Icons.work),
        label: _careerLabel(hasCompany: hasCompany, companyName: companyName),
      ),
      const NavigationDestination(
        icon: Icon(Icons.person_outline),
        selectedIcon: Icon(Icons.person),
        label: 'Profil',
      ),
    ];
  }

  String _careerLabel({
    required bool hasCompany,
    required String? companyName,
  }) {
    if (!hasCompany) return 'Alternance';

    final cleanedName = companyName?.trim();
    if (cleanedName == null || cleanedName.isEmpty) return 'Entreprise';
    if (cleanedName.length <= 11) return cleanedName;
    return '${cleanedName.substring(0, 10)}…';
  }
}
