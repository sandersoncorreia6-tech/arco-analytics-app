import 'package:flutter/material.dart';
import '../widgets/responsive_frame.dart';
import 'analytics_screen.dart';
import 'competition_hub_screen.dart';
import 'home_screen.dart';
import 'insights_screen.dart';
import 'more_screen.dart';
import 'team_screen.dart';

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int index = 0;

  static const screens = [
    HomeScreen(),
    CompetitionHubScreen(),
    TeamScreen(),
    AnalyticsScreen(),
    InsightsScreen(),
    MoreScreen(),
  ];

  static const destinations = [
    NavigationRailDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: Text('Home')),
    NavigationRailDestination(icon: Icon(Icons.sports_basketball_outlined), selectedIcon: Icon(Icons.sports_basketball), label: Text('Competições')),
    NavigationRailDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: Text('Equipe')),
    NavigationRailDestination(icon: Icon(Icons.query_stats_outlined), selectedIcon: Icon(Icons.query_stats), label: Text('Analytics')),
    NavigationRailDestination(icon: Icon(Icons.lightbulb_outline), selectedIcon: Icon(Icons.lightbulb), label: Text('Insights')),
    NavigationRailDestination(icon: Icon(Icons.more_horiz), selectedIcon: Icon(Icons.more_horiz_rounded), label: Text('Mais')),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 900;
        final content = ResponsiveFrame(
          child: SafeArea(
            child: IndexedStack(index: index, children: screens),
          ),
        );

        if (desktop) {
          return Scaffold(
            body: Row(
              children: [
                SafeArea(
                  child: NavigationRail(
                    selectedIndex: index,
                    onDestinationSelected: (value) => setState(() => index = value),
                    extended: constraints.maxWidth >= 1180,
                    leading: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      child: _ArcoMark(),
                    ),
                    destinations: destinations,
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: content),
              ],
            ),
          );
        }

        return Scaffold(
          body: content,
          bottomNavigationBar: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: (value) => setState(() => index = value),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
              NavigationDestination(icon: Icon(Icons.sports_basketball_outlined), selectedIcon: Icon(Icons.sports_basketball), label: 'Ligas'),
              NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: 'Equipe'),
              NavigationDestination(icon: Icon(Icons.query_stats_outlined), selectedIcon: Icon(Icons.query_stats), label: 'Analytics'),
              NavigationDestination(icon: Icon(Icons.lightbulb_outline), selectedIcon: Icon(Icons.lightbulb), label: 'Insights'),
              NavigationDestination(icon: Icon(Icons.more_horiz), label: 'Mais'),
            ],
          ),
        );
      },
    );
  }
}

class _ArcoMark extends StatelessWidget {
  const _ArcoMark();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'ARCO Analytics',
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.sports_basketball_rounded),
      ),
    );
  }
}
