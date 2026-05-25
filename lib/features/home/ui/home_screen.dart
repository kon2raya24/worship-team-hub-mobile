import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/supabase_client.dart';
import '../../../core/theme.dart';
import '../../../data/sync/providers.dart';
import '../../../data/sync/sync_service.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = currentUser?.email ?? 'team';
    // Fire-and-forget initial sync. Errors are surfaced via the badge below.
    final sync = ref.watch(startupSyncProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
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
            icon: const Icon(Icons.logout, size: 20),
            tooltip: 'Sign out',
            onPressed: () => supabase.auth.signOut(),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Signed in as $email', style: Sanctuary.mono(fontSize: 11)),
            const SizedBox(height: 8),
            Text('Welcome back', style: Sanctuary.display(fontSize: 28)),
            const SizedBox(height: 12),
            _SyncBadge(state: sync),
            const SizedBox(height: 24),
            _HomeTile(
              title: 'Songs',
              subtitle: 'Chord charts · offline',
              icon: Icons.library_music_outlined,
              accent: Sanctuary.auroraViolet,
              onTap: () => context.go('/songs'),
            ),
            const SizedBox(height: 12),
            _HomeTile(
              title: 'Setlists',
              subtitle: 'Upcoming services',
              icon: Icons.queue_music_outlined,
              accent: Sanctuary.auroraCyan,
              onTap: () => context.go('/setlists'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SyncBadge extends StatelessWidget {
  const _SyncBadge({required this.state});

  final AsyncValue<SyncResult> state;

  @override
  Widget build(BuildContext context) {
    final (icon, label, color) = switch (state) {
      AsyncLoading() => (
        Icons.sync,
        'Syncing…',
        Sanctuary.auroraCyan,
      ),
      AsyncError(:final error) => (
        Icons.cloud_off_outlined,
        'Offline · $error',
        Sanctuary.auroraMagenta,
      ),
      AsyncData(:final value) when value == SyncResult.failed => (
        Icons.cloud_off_outlined,
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

class _HomeTile extends StatelessWidget {
  const _HomeTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  final String title;
  final String subtitle;
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
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  border: Border.all(color: accent.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(Sanctuary.radiusMd),
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Sanctuary.display(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Sanctuary.muted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Sanctuary.muted),
            ],
          ),
        ),
      ),
    );
  }
}
