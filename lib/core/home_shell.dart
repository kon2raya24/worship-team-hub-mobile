import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'theme.dart';

/// Wraps every primary route with a persistent bottom navigation bar.
/// Each [StatefulShellBranch] keeps its own nav stack — going into a
/// song detail and tapping a different tab preserves the song detail
/// when you come back to the Songs tab.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.navShell});

  final StatefulNavigationShell navShell;

  static const _items = [
    _NavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Home',
    ),
    _NavItem(
      icon: Icons.library_music_outlined,
      activeIcon: Icons.library_music,
      label: 'Songs',
    ),
    _NavItem(
      icon: Icons.queue_music_outlined,
      activeIcon: Icons.queue_music,
      label: 'Setlists',
    ),
    _NavItem(
      icon: Icons.calendar_month_outlined,
      activeIcon: Icons.calendar_month,
      label: 'Schedule',
    ),
    _NavItem(
      icon: Icons.more_horiz,
      activeIcon: Icons.more_horiz,
      label: 'More',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: navShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Sanctuary.ink1.withValues(alpha: 0.95),
          border: const Border(top: BorderSide(color: Sanctuary.hairline)),
        ),
        child: SafeArea(
          top: false,
          child: NavigationBarTheme(
            data: NavigationBarThemeData(
              backgroundColor: Colors.transparent,
              elevation: 0,
              indicatorColor: Sanctuary.auroraViolet.withValues(alpha: 0.18),
              iconTheme: WidgetStateProperty.resolveWith(
                (states) => IconThemeData(
                  color: states.contains(WidgetState.selected)
                      ? Sanctuary.auroraViolet
                      : Sanctuary.muted,
                  size: 22,
                ),
              ),
              labelTextStyle: WidgetStateProperty.resolveWith(
                (states) => TextStyle(
                  color: states.contains(WidgetState.selected)
                      ? Sanctuary.foreground
                      : Sanctuary.muted,
                  fontSize: 11,
                  fontWeight: states.contains(WidgetState.selected)
                      ? FontWeight.w600
                      : FontWeight.w500,
                ),
              ),
            ),
            child: NavigationBar(
              height: 60,
              selectedIndex: navShell.currentIndex,
              labelBehavior:
                  NavigationDestinationLabelBehavior.alwaysShow,
              onDestinationSelected: (i) {
                // Tapping the active tab pops to the branch's root — like
                // iOS / Android system pattern. Otherwise switch branches
                // while preserving each branch's nav stack.
                navShell.goBranch(
                  i,
                  initialLocation: i == navShell.currentIndex,
                );
              },
              destinations: _items
                  .map(
                    (item) => NavigationDestination(
                      icon: Icon(item.icon),
                      selectedIcon: Icon(item.activeIcon),
                      label: item.label,
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
  final IconData icon;
  final IconData activeIcon;
  final String label;
}
