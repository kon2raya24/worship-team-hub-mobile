import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';

class GamesIndexScreen extends StatelessWidget {
  const GamesIndexScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        // Tinted ink so chord/grid content doesn't peek through when
        // scrolled to the top.
        backgroundColor: cs.surfaceContainer.withValues(alpha: 0.85),
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 20),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: const Text('Games'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'PRACTICE',
              style: Sanctuary.mono(fontSize: 10, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            Text(
              'Music-theory drills for the worship team.',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 18),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.05,
              children: const [
                _GameTile(
                  title: 'Transpose',
                  icon: Icons.swap_horiz,
                  accent: Sanctuary.auroraViolet,
                  path: '/games/transpose',
                ),
                _GameTile(
                  title: 'Nashville',
                  icon: Icons.tag,
                  accent: Sanctuary.auroraAmber,
                  path: '/games/nashville',
                ),
                _GameTile(
                  title: 'Capo math',
                  icon: Icons.straighten,
                  accent: Sanctuary.success,
                  path: '/games/capo',
                ),
                _GameTile(
                  title: 'Key sigs',
                  icon: Icons.vpn_key_outlined,
                  accent: Sanctuary.auroraCyan,
                  path: '/games/keys',
                ),
                _GameTile(
                  title: 'BPM tapper',
                  icon: Icons.timer_outlined,
                  accent: Sanctuary.auroraMagenta,
                  path: '/games/bpm',
                ),
                _GameTile(
                  title: 'Intervals',
                  icon: Icons.linear_scale,
                  accent: Sanctuary.auroraMagenta,
                  path: '/games/intervals',
                ),
                _GameTile(
                  title: 'Chord tones',
                  icon: Icons.adjust,
                  accent: Sanctuary.auroraCyan,
                  path: '/games/chord-tones',
                ),
                _GameTile(
                  title: 'Relative key',
                  icon: Icons.swap_vert,
                  accent: Sanctuary.auroraViolet,
                  path: '/games/relative',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact icon-in-a-box tile. No outer card — just the coloured icon
/// container with the title underneath. The whole footprint is tappable.
class _GameTile extends StatelessWidget {
  const _GameTile({
    required this.title,
    required this.icon,
    required this.accent,
    required this.path,
  });

  final String title;
  final IconData icon;
  final Color accent;
  final String path;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(Sanctuary.radiusLg),
        onTap: () => context.push(path),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? Sanctuary.glass1 : Sanctuary.lightGlass1,
            border: Border.all(color: cs.outlineVariant),
            borderRadius: BorderRadius.circular(Sanctuary.radiusLg),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  border: Border.all(color: accent.withValues(alpha: 0.4)),
                  borderRadius: BorderRadius.circular(Sanctuary.radiusMd),
                ),
                child: Icon(icon, color: accent, size: 20),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
