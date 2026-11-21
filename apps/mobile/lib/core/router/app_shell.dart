import 'package:flutter/material.dart';
import 'package:nexus_design_tokens/nexus_tokens.dart';

import '../../features/chat/presentation/chat_screen.dart';
import '../../features/discovery/presentation/discovery_screen.dart';
import '../../features/lobby/presentation/lobby_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../widgets/nexus_ui_kit.dart';

/// Responsive application shell adapting cleanly between:
/// - `< 600px`: Bottom Navigation Bar (4 tabs, Thumb Zone)
/// - `>= 600px`: Left NavigationRail (Tablet & Desktop 2nd-Monitor parity)
class NexusAppShell extends StatefulWidget {
  const NexusAppShell({this.initialTabIndex = 0, super.key});

  final int initialTabIndex;

  @override
  State<NexusAppShell> createState() => _NexusAppShellState();
}

class _NexusAppShellState extends State<NexusAppShell> {
  late int _currentIndex;

  static const List<Widget> _pages = <Widget>[
    DiscoveryScreen(),
    LobbyScreen(),
    MatchesListScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final useRail = width >= NexusBreakpoints.tabletMin;

    if (useRail) {
      return Scaffold(
        body: Row(
          children: <Widget>[
            NavigationRail(
              selectedIndex: _currentIndex,
              backgroundColor: NexusColors.bgSurface,
              indicatorColor: NexusColors.brandPrimary.withValues(alpha: 0.25),
              labelType: NavigationRailLabelType.all,
              leading: const Padding(
                padding: EdgeInsets.symmetric(vertical: NexusSpacing.md),
                child: NexusBrandLogo(compact: true),
              ),
              onDestinationSelected: (i) => setState(() => _currentIndex = i),
              destinations: const <NavigationRailDestination>[
                NavigationRailDestination(
                  icon: Icon(Icons.explore_outlined),
                  selectedIcon: Icon(Icons.explore_rounded),
                  label: Text('Drop'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.bolt_outlined),
                  selectedIcon: Icon(Icons.bolt_rounded),
                  label: Text('Duo Agora'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.chat_bubble_outline_rounded),
                  selectedIcon: Icon(Icons.chat_bubble_rounded),
                  label: Text('Chat E2EE'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.person_outline_rounded),
                  selectedIcon: Icon(Icons.person_rounded),
                  label: Text('Perfil'),
                ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: _pages[_currentIndex]),
          ],
        ),
      );
    }

    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        backgroundColor: NexusColors.bgSurface,
        indicatorColor: NexusColors.brandPrimary.withValues(alpha: 0.25),
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore_rounded),
            label: 'Drop',
          ),
          NavigationDestination(
            icon: Icon(Icons.bolt_outlined),
            selectedIcon: Icon(Icons.bolt_rounded),
            label: 'Duo Agora',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            selectedIcon: Icon(Icons.chat_bubble_rounded),
            label: 'Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
