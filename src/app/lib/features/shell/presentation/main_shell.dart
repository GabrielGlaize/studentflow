import 'package:flutter/material.dart';
import 'package:studyflow_app/core/app_scope.dart';
import 'package:studyflow_app/features/agenda/presentation/agenda_page.dart';
import 'package:studyflow_app/features/apprenticeships/presentation/apprenticeships_page.dart';
import 'package:studyflow_app/features/company/presentation/company_page.dart';
import 'package:studyflow_app/features/dashboard/presentation/dashboard_page.dart';
import 'package:studyflow_app/features/profile/presentation/profile_page.dart';
import 'package:studyflow_app/features/schedule/presentation/schedule_page.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;
  String _agendaInitialCategory = 'school';

  @override
  Widget build(BuildContext context) {
    final settingsController = AppScope.of(context).settingsController;

    return AnimatedBuilder(
      animation: settingsController,
      builder: (context, _) {
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
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFD7E3EA))),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x10073B4C),
                      blurRadius: 30,
                      offset: Offset(0, -8),
                    ),
                  ],
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
