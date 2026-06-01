import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';

/// Landing page for the bottom-nav "More" tab — surfaces every primary
/// destination not already in the bottom bar (Devotions, Prayer,
/// Announcements, Games, Team, Settings).
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  static const _items = <_MoreItem>[
    _MoreItem(
      title: 'Devotions',
      subtitle: 'Weekly reflections',
      icon: Icons.menu_book_outlined,
      accent: Sanctuary.auroraAmber,
      path: '/devotions',
    ),
    _MoreItem(
      title: 'Prayer',
      subtitle: 'Requests + answered',
      icon: Icons.favorite_outline,
      accent: Sanctuary.auroraMagenta,
      path: '/prayer',
    ),
    _MoreItem(
      title: 'Announcements',
      subtitle: 'Team updates',
      icon: Icons.campaign_outlined,
      accent: Sanctuary.auroraCyan,
      path: '/announcements',
    ),
    _MoreItem(
      title: 'Games',
      subtitle: 'Music-theory drills',
      icon: Icons.sports_esports_outlined,
      accent: Sanctuary.auroraViolet,
      path: '/games',
    ),
    _MoreItem(
      title: 'Team',
      subtitle: 'Members + roles',
      icon: Icons.groups_outlined,
      accent: Sanctuary.auroraAmber,
      path: '/team',
    ),
    _MoreItem(
      title: 'Settings',
      subtitle: 'Account + sign-in',
      icon: Icons.settings_outlined,
      accent: Sanctuary.muted,
      path: '/settings',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: cs.surfaceContainer.withValues(alpha: 0.85),
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: const Text('More'),
      ),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: _items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) => _MoreCard(item: _items[i]),
        ),
      ),
    );
  }
}

class _MoreItem {
  const _MoreItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.path,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final String path;
}

class _MoreCard extends StatelessWidget {
  const _MoreCard({required this.item});
  final _MoreItem item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent =
        item.accent == Sanctuary.muted ? cs.onSurfaceVariant : item.accent;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(Sanctuary.radiusLg),
        onTap: () => context.push(item.path),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? Sanctuary.glass1 : Sanctuary.lightGlass1,
            border: Border.all(color: accent.withValues(alpha: 0.22)),
            borderRadius: BorderRadius.circular(Sanctuary.radiusLg),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  border:
                      Border.all(color: accent.withValues(alpha: 0.4)),
                  borderRadius: BorderRadius.circular(Sanctuary.radiusMd),
                ),
                child: Icon(item.icon, color: accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  size: 20, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
