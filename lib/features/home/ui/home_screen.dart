import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/supabase_client.dart';
import '../../../core/theme.dart';
import '../../../data/db/app_db.dart';
import '../../../data/sync/connectivity.dart';
import '../../../data/sync/providers.dart';
import '../../../data/sync/sync_service.dart';
import '../../auth/auth_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _SignOutDialog(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).value;
    final name = (profile?.displayName ?? '').trim();
    // Offline mode has no live Supabase session, so currentUser.email is
    // null. The activeEmailProvider falls back to the email we stashed on
    // the last successful sign-in.
    final email = currentUser?.email ?? ref.watch(activeEmailProvider).value ?? '';
    final greetTarget = name.isNotEmpty
        ? name
        : email.isNotEmpty
            ? email.split('@').first
            : 'team';
    final offlineMode = ref.watch(offlineModeProvider);
    final connectivity = ref.watch(connectivityProvider);
    final connectivityKnown = connectivity.value != null;
    final online = connectivityKnown && isOnline(connectivity.value!);
    // Surface the amber "offline" banner whenever the device is actually
    // offline OR we entered offline mode via the login screen. Without the
    // connectivity check, a user who cold-starts with a still-valid cached
    // Supabase session never saw the banner even though writes would fail.
    final offline = offlineMode || (connectivityKnown && !online);
    // Fire-and-forget initial sync. Errors are surfaced via the badge below.
    final sync = offline
        ? const AsyncValue<SyncResult>.data(SyncResult.skipped)
        : ref.watch(startupSyncProvider);
    wireAutoSync(ref);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        // Tinted ink so scrolling content doesn't show through and clip
        // weirdly at the AppBar boundary.
        backgroundColor: Sanctuary.ink1.withValues(alpha: 0.85),
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: const Text('Worship Hub'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: 'Sync',
            onPressed: sync.isLoading
                ? null
                : () => ref.refresh(startupSyncProvider.future),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 20),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
          IconButton(
            icon: const Icon(Icons.logout, size: 20),
            tooltip: 'Sign out',
            onPressed: () => _signOut(context),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            if (offline)
              _OfflineBanner()
            else
              _SyncBadge(state: sync, online: online),
            const SizedBox(height: 16),

            // ─── Hero: time greeting + gradient verse ────────────────
            _HeroCard(firstName: greetTarget.split(' ').first),
            const SizedBox(height: 16),

            // ─── 4 stat cards: Library / Prayers / Next Role / Pinned
            _DashboardStats(),
            const SizedBox(height: 16),

            // ─── 2 feature cards: Next Sunday + Latest Devotion ──────
            const _DashboardFeatures(),
            const SizedBox(height: 16),

            // ─── Practice (all 8 games in a compact grid) ────────────
            const _PracticeSection(),
            const SizedBox(height: 16),

            // ─── Pinned announcements ────────────────────────────────
            const _PinnedAnnouncementsSection(),
          ],
        ),
      ),
    );
  }
}

class _SyncBadge extends StatelessWidget {
  const _SyncBadge({required this.state, required this.online});

  final AsyncValue<SyncResult> state;
  final bool online;

  @override
  Widget build(BuildContext context) {
    final (icon, label, color) = switch ((state, online)) {
      (_, false) => (
        Icons.cloud_off_outlined,
        'Offline · using cached data',
        Sanctuary.auroraAmber,
      ),
      (AsyncLoading(), _) => (
        Icons.sync,
        'Syncing…',
        Sanctuary.auroraCyan,
      ),
      (AsyncError(:final error), _) => (
        Icons.error_outline,
        'Sync failed · $error',
        Sanctuary.auroraMagenta,
      ),
      (AsyncData(:final value), _) when value == SyncResult.failed => (
        Icons.error_outline,
        'Last sync failed — pull to retry',
        Sanctuary.auroraMagenta,
      ),
      _ => (
        Icons.cloud_done_outlined,
        'Synced ${DateFormat.jm().format(DateTime.now())}',
        Sanctuary.auroraCyan,
      ),
    };
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(label, style: Sanctuary.mono(fontSize: 11, color: color)),
      ],
    );
  }
}

/// Shown on the home screen when the user signed in via biometric while
/// offline. The Drift cache is readable; writes silently fail.
class _OfflineBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Sanctuary.auroraAmber.withValues(alpha: 0.1),
        border: Border.all(color: Sanctuary.auroraAmber.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(Sanctuary.radiusMd),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off,
              size: 14, color: Sanctuary.auroraAmber),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Offline · using cached data from your last sync. '
              'Posting + edits are paused until you\'re back online.',
              style: const TextStyle(
                color: Sanctuary.auroraAmber,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Confirms sign-out and runs supabase.auth.signOut() with a visible spinner
/// so the user doesn't tap again thinking nothing happened.
class _SignOutDialog extends ConsumerStatefulWidget {
  const _SignOutDialog();

  @override
  ConsumerState<_SignOutDialog> createState() => _SignOutDialogState();
}

class _SignOutDialogState extends ConsumerState<_SignOutDialog> {
  bool _busy = false;

  Future<void> _confirm() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      // Clear offline-mode regardless so the next launch shows /login.
      ref.read(offlineModeProvider.notifier).state = false;
      await supabase.auth.signOut();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not sign out. Try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Sanctuary.ink2,
      title: const Text('Sign out?'),
      content: const Text(
        'You\'ll be returned to the login screen. Your offline cache and '
        'fingerprint enrolment stay on this device.',
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Stay signed in'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Sanctuary.destructive,
          ),
          onPressed: _busy ? null : _confirm,
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Sign out'),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// Dashboard sections — mirrors the web home page (hero + stats + features
// + practice + pinned announcements).
// ════════════════════════════════════════════════════════════════════════

String _greetingFor(int hour) {
  if (hour < 5) return 'Good evening';
  if (hour < 12) return 'Good morning';
  if (hour < 18) return 'Good afternoon';
  return 'Good evening';
}

/// Aurora hero card with the worship-team verse. Uses a real-time clock
/// snapshot for the eyebrow so the greeting matches the phone's local
/// time, not UTC.
class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.firstName});
  final String firstName;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final greet = _greetingFor(now.hour).toUpperCase();
    final weekday = DateFormat('EEEE').format(now).toUpperCase();
    final name = firstName.isEmpty ? 'Team' : firstName;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1B0E3D),
            Color(0xFF0A1A33),
            Color(0xFF1B0A2A),
          ],
        ),
        border: Border.all(color: Sanctuary.hairline),
        borderRadius: BorderRadius.circular(Sanctuary.radiusLg),
        boxShadow: [
          BoxShadow(
            color: Sanctuary.auroraViolet.withValues(alpha: 0.18),
            blurRadius: 24,
            spreadRadius: -8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome,
                  size: 12, color: Sanctuary.muted),
              const SizedBox(width: 6),
              Text(
                '$greet · $weekday',
                style: Sanctuary.mono(fontSize: 10, color: Sanctuary.muted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Gradient text — paint only the highlighted middle phrase with
          // the aurora gradient, leave the rest white.
          RichText(
            text: TextSpan(
              style: Sanctuary.display(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: Sanctuary.foreground,
              ).copyWith(height: 1.12),
              children: [
                TextSpan(text: '$name, '),
                WidgetSpan(
                  child: ShaderMask(
                    shaderCallback: (rect) => const LinearGradient(
                      colors: [
                        Sanctuary.auroraCyan,
                        Sanctuary.auroraViolet,
                        Sanctuary.auroraMagenta,
                      ],
                    ).createShader(rect),
                    child: Text(
                      'let everything that has breath',
                      style: Sanctuary.display(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ).copyWith(height: 1.12),
                    ),
                  ),
                ),
                const TextSpan(text: ' praise the Lord.'),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "— Psalm 150:6. Here's what your worship team is up to today.",
            style: const TextStyle(
              color: Sanctuary.muted,
              fontSize: 12,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

/// 2×2 grid of count cards. Songs / Open Prayers / Your Next Role /
/// Pinned. Matches the web home's stat-card row.
class _DashboardStats extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songsCount = ref.watch(songsStreamProvider).value?.length;
    final openPrayers = ref
        .watch(prayerRequestsStreamProvider)
        .value
        ?.where((PrayerRequestRow p) => !p.isAnswered)
        .length;
    final pinnedCount = ref
        .watch(announcementsStreamProvider)
        .value
        ?.where((AnnouncementRow a) => a.pinned)
        .length;

    final myId = currentUser?.id;
    final myNext = myId == null
        ? null
        : ref
            .watch(upcomingScheduleStreamProvider)
            .value
            ?.cast<UpcomingAssignment?>()
            .firstWhere(
              (a) => a?.assignment.userId == myId,
              orElse: () => null,
            );

    final nextRoleValue = myNext?.assignment.role ?? '—';
    final nextRoleSub = myNext == null
        ? 'Not assigned'
        : DateFormat('EEEE, MMM d').format(myNext.assignment.serviceDate);

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.4,
      children: [
        _StatCard(
          label: 'Song library',
          value: songsCount?.toString() ?? '—',
          icon: Icons.library_music_outlined,
          accent: Sanctuary.auroraViolet,
          path: '/songs',
        ),
        _StatCard(
          label: 'Open prayers',
          value: openPrayers?.toString() ?? '—',
          icon: Icons.favorite_outline,
          accent: openPrayers != null && openPrayers > 0
              ? Sanctuary.auroraMagenta
              : Sanctuary.auroraViolet,
          path: '/prayer',
        ),
        _StatCard(
          label: 'Your next role',
          value: nextRoleValue,
          sub: nextRoleSub,
          icon: Icons.mic_none_outlined,
          accent: Sanctuary.auroraCyan,
          path: '/schedule',
        ),
        _StatCard(
          label: 'Pinned',
          value: pinnedCount?.toString() ?? '—',
          icon: Icons.push_pin_outlined,
          accent: Sanctuary.auroraAmber,
          path: '/announcements',
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    required this.path,
    this.sub,
  });
  final String label;
  final String value;
  final String? sub;
  final IconData icon;
  final Color accent;
  final String path;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(Sanctuary.radiusLg),
        onTap: () => context.push(path),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Sanctuary.glass1,
            border: Border.all(color: accent.withValues(alpha: 0.22)),
            borderRadius: BorderRadius.circular(Sanctuary.radiusLg),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  border: Border.all(color: accent.withValues(alpha: 0.35)),
                  borderRadius: BorderRadius.circular(Sanctuary.radiusMd),
                ),
                child: Icon(icon, color: accent, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: Sanctuary.mono(
                        fontSize: 9,
                        color: Sanctuary.muted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      style: Sanctuary.display(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (sub != null && sub!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Text(
                          sub!,
                          style: const TextStyle(
                            color: Sanctuary.muted,
                            fontSize: 10,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Two stacked feature cards: Next Sunday + Latest Devotion. Each shows a
/// short headline and a CTA — falls back to a "Create one" prompt when
/// the data is empty.
class _DashboardFeatures extends ConsumerWidget {
  const _DashboardFeatures();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nextSetlist =
        ref.watch(upcomingSetlistsStreamProvider).value?.firstOrNull;
    final devotion = ref.watch(devotionsStreamProvider).value?.firstOrNull;

    return Column(
      children: [
        _FeatureCard(
          icon: Icons.calendar_today_outlined,
          eyebrow: 'NEXT SUNDAY',
          title: nextSetlist == null
              ? 'No setlist yet'
              : DateFormat('EEEE, MMM d').format(nextSetlist.serviceDate),
          body: nextSetlist == null
              ? 'Plan a setlist to get the band ready.'
              : (nextSetlist.theme?.trim().isNotEmpty == true
                  ? nextSetlist.theme!
                  : 'Theme to be announced'),
          cta: nextSetlist == null ? 'Create setlist' : 'Open setlist',
          path: nextSetlist == null
              ? '/setlists'
              : '/setlists/${nextSetlist.id}',
          accent: Sanctuary.auroraCyan,
        ),
        const SizedBox(height: 10),
        _FeatureCard(
          icon: Icons.menu_book_outlined,
          eyebrow: 'LATEST DEVOTION',
          title: devotion?.title ?? 'No devotions yet',
          body: devotion == null
              ? 'Share the first devotion with your team.'
              : (devotion.scriptureRef?.trim().isNotEmpty == true
                  ? devotion.scriptureRef!
                  : ''),
          cta: devotion == null ? 'Write one' : 'Read devotion',
          path: devotion == null ? '/devotions' : '/devotions/${devotion.id}',
          accent: Sanctuary.auroraViolet,
        ),
      ],
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.cta,
    required this.path,
    required this.accent,
  });
  final IconData icon;
  final String eyebrow;
  final String title;
  final String body;
  final String cta;
  final String path;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(Sanctuary.radiusLg),
        onTap: () => context.push(path),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Sanctuary.glass1,
            border: Border.all(color: accent.withValues(alpha: 0.25)),
            borderRadius: BorderRadius.circular(Sanctuary.radiusLg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      border:
                          Border.all(color: accent.withValues(alpha: 0.4)),
                      borderRadius: BorderRadius.circular(Sanctuary.radiusSm),
                    ),
                    child: Icon(icon, color: accent, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(eyebrow,
                      style: Sanctuary.mono(
                          fontSize: 10, color: Sanctuary.muted)),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: Sanctuary.display(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (body.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    color: Sanctuary.muted,
                    fontSize: 13,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    cta,
                    style: TextStyle(
                      color: accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward, size: 14, color: accent),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Practice" — surfaces all 8 games as compact icon tiles inside a card.
class _PracticeSection extends StatelessWidget {
  const _PracticeSection();

  static const _games = <(String, IconData, Color, String)>[
    ('Transpose', Icons.swap_horiz, Sanctuary.auroraViolet, '/games/transpose'),
    ('Nashville', Icons.tag, Sanctuary.auroraAmber, '/games/nashville'),
    ('Capo math', Icons.straighten, Sanctuary.success, '/games/capo'),
    ('Key sigs', Icons.vpn_key_outlined, Sanctuary.auroraCyan, '/games/keys'),
    ('BPM tapper', Icons.timer_outlined, Sanctuary.auroraMagenta, '/games/bpm'),
    ('Intervals', Icons.linear_scale, Sanctuary.auroraMagenta,
        '/games/intervals'),
    ('Chord tones', Icons.adjust, Sanctuary.auroraCyan, '/games/chord-tones'),
    ('Relative key', Icons.swap_vert, Sanctuary.auroraViolet,
        '/games/relative'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Sanctuary.glass1,
        border: Border.all(color: Sanctuary.hairline),
        borderRadius: BorderRadius.circular(Sanctuary.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Sanctuary.auroraViolet.withValues(alpha: 0.15),
                  border: Border.all(
                      color: Sanctuary.auroraViolet.withValues(alpha: 0.4)),
                  borderRadius: BorderRadius.circular(Sanctuary.radiusSm),
                ),
                child: const Icon(Icons.sports_esports_outlined,
                    color: Sanctuary.auroraViolet, size: 16),
              ),
              const SizedBox(width: 10),
              Text(
                'Practice',
                style: Sanctuary.display(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              InkWell(
                borderRadius: BorderRadius.circular(Sanctuary.radiusSm),
                onTap: () => context.push('/games'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 4),
                  child: Row(
                    children: [
                      Text(
                        'All games',
                        style: Sanctuary.mono(
                          fontSize: 11,
                          color: Sanctuary.muted,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward,
                          size: 12, color: Sanctuary.muted),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 0.95,
            children: _games
                .map((g) => _PracticeTile(
                      title: g.$1,
                      icon: g.$2,
                      accent: g.$3,
                      path: g.$4,
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _PracticeTile extends StatelessWidget {
  const _PracticeTile({
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(Sanctuary.radiusMd),
        onTap: () => context.push(path),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          decoration: BoxDecoration(
            color: Sanctuary.glass1,
            border: Border.all(color: Sanctuary.hairline),
            borderRadius: BorderRadius.circular(Sanctuary.radiusMd),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  border: Border.all(color: accent.withValues(alpha: 0.4)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: accent, size: 16),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Sanctuary.foreground,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Pinned announcements" — list of the announcements flagged pinned.
class _PinnedAnnouncementsSection extends ConsumerWidget {
  const _PinnedAnnouncementsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pinned = (ref.watch(announcementsStreamProvider).value ?? const [])
        .where((a) => a.pinned)
        .take(3)
        .toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Sanctuary.glass1,
        border: Border.all(color: Sanctuary.hairline),
        borderRadius: BorderRadius.circular(Sanctuary.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Sanctuary.auroraMagenta.withValues(alpha: 0.15),
                  border: Border.all(
                      color: Sanctuary.auroraMagenta.withValues(alpha: 0.4)),
                  borderRadius: BorderRadius.circular(Sanctuary.radiusSm),
                ),
                child: const Icon(Icons.campaign_outlined,
                    color: Sanctuary.auroraMagenta, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Pinned announcements',
                  style: Sanctuary.display(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(Sanctuary.radiusSm),
                onTap: () => context.push('/announcements'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 4),
                  child: Row(
                    children: [
                      Text('All news',
                          style: Sanctuary.mono(
                              fontSize: 11, color: Sanctuary.muted)),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward,
                          size: 12, color: Sanctuary.muted),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (pinned.isEmpty)
            const Text(
              'Nothing pinned right now.',
              style: TextStyle(color: Sanctuary.muted, fontSize: 13),
            )
          else
            ...pinned.map(
              (a) => Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
                  decoration: const BoxDecoration(
                    border: Border(
                      left: BorderSide(
                          color: Sanctuary.auroraMagenta, width: 2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.title,
                        style: Sanctuary.display(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (a.body.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            a.body,
                            style: const TextStyle(
                              color: Sanctuary.muted,
                              fontSize: 12,
                              height: 1.4,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}


