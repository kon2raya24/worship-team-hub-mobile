import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/sync/connectivity.dart';
import '../data/sync/sync_service.dart';
import 'push_service.dart';
import 'supabase_client.dart';
import 'theme.dart';

/// Wraps every primary route with a persistent bottom navigation bar.
/// Each [StatefulShellBranch] keeps its own nav stack — going into a
/// song detail and tapping a different tab preserves the song detail
/// when you come back to the Songs tab.
///
/// Because the shell stays mounted for the whole signed-in session, it's
/// also where we keep the data fresh: pull from Supabase whenever the app
/// returns to the foreground, plus a light poll while it's open and online.
/// Without this the local Drift cache only refreshed on cold start, on an
/// offline→online flip, or when the user tapped Sync — so records added on
/// the web or by a teammate stayed invisible until a manual sync.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key, required this.navShell});

  final StatefulNavigationShell navShell;

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell>
    with WidgetsBindingObserver {
  /// How often to refresh while the app is open and online. Frequent enough
  /// that a teammate's change shows up quickly; gentle enough on data/battery.
  static const _pollInterval = Duration(seconds: 30);

  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startPolling();
    _registerPush();
  }

  void _registerPush() {
    final user = supabase.auth.currentUser;
    if (user != null) unawaited(PushService.registerForUser(user.id));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Coming back to the app: pull immediately so the user sees current
      // data, then resume the steady poll.
      _syncIfOnline();
      _startPolling();
    } else if (state == AppLifecycleState.paused) {
      // No point polling in the background.
      _pollTimer?.cancel();
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _syncIfOnline());
  }

  void _syncIfOnline() {
    if (!mounted) return;
    // Only skip when we positively know we're offline; if connectivity is
    // still unknown, attempt the sync and let the network call fail fast.
    final conn = ref.read(connectivityProvider).value;
    if (conn != null && !isOnline(conn)) return;
    unawaited(ref.read(syncServiceProvider).syncAll());
  }

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
      body: widget.navShell,
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
              selectedIndex: widget.navShell.currentIndex,
              labelBehavior:
                  NavigationDestinationLabelBehavior.alwaysShow,
              onDestinationSelected: (i) {
                // Tapping the active tab pops to the branch's root — like
                // iOS / Android system pattern. Otherwise switch branches
                // while preserving each branch's nav stack.
                widget.navShell.goBranch(
                  i,
                  initialLocation: i == widget.navShell.currentIndex,
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
