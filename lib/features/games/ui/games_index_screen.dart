import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';

class GamesIndexScreen extends StatelessWidget {
  const GamesIndexScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 20),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: const Text('Games'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _GameCard(
            title: 'Transpose Trainer',
            blurb:
                'A progression appears in one key. Play it back in the target key. '
                'Sharpens the muscle every guitarist + keys player uses each Sunday.',
            icon: Icons.swap_horiz,
            accent: Sanctuary.auroraViolet,
            onTap: () => context.push('/games/transpose'),
          ),
          const SizedBox(height: 12),
          _GameCard(
            title: 'Key Signature Quiz',
            blurb:
                'How many sharps in E? How many flats in Eb? Quick-fire 10-round '
                'warm-up before practice.',
            icon: Icons.vpn_key_outlined,
            accent: Sanctuary.auroraCyan,
            onTap: () => context.push('/games/keys'),
          ),
          const SizedBox(height: 12),
          _GameCard(
            title: 'BPM Tapper',
            blurb:
                'Tap to a tempo and see how close you stay to the target. Great '
                'for drummers and anyone running click track.',
            icon: Icons.timer_outlined,
            accent: Sanctuary.auroraMagenta,
            onTap: () => context.push('/games/bpm'),
          ),
        ],
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({
    required this.title,
    required this.blurb,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  final String title;
  final String blurb;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(Sanctuary.radiusLg),
        onTap: onTap,
        child: GlassCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.35),
                      ),
                      borderRadius: BorderRadius.circular(Sanctuary.radiusMd),
                    ),
                    child: Icon(icon, color: accent, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'MINI-GAME',
                    style: Sanctuary.mono(fontSize: 10, color: accent),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: Sanctuary.display(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                blurb,
                style: const TextStyle(
                  color: Sanctuary.muted,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
