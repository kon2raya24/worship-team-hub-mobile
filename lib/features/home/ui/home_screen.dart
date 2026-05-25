import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/supabase_client.dart';
import '../../../core/theme.dart';
import '../../../data/sync/connectivity.dart';
import '../../../data/sync/providers.dart';
import '../../../data/sync/sync_service.dart';
import '../../auth/biometric_service.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _signOut(WidgetRef ref) async {
    // Clear the biometric preference too so the next account doesn't inherit it.
    final bio = ref.read(biometricServiceProvider);
    await bio?.setEnabled(false);
    ref.read(unlockSessionProvider.notifier).relock();
    await supabase.auth.signOut();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = currentUser?.email ?? 'team';
    // Fire-and-forget initial sync. Errors are surfaced via the badge below.
    final sync = ref.watch(startupSyncProvider);
    final connectivity = ref.watch(connectivityProvider);
    final online = connectivity.value != null && isOnline(connectivity.value!);
    wireAutoSync(ref);
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
            onPressed: () => _signOut(ref),
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
            _SyncBadge(state: sync, online: online),
            const SizedBox(height: 16),
            const _BiometricToggle(),
            const SizedBox(height: 16),
            _HomeTile(
              title: 'Songs',
              subtitle: 'Chord charts · offline',
              icon: Icons.library_music_outlined,
              accent: Sanctuary.auroraViolet,
              onTap: () => context.push('/songs'),
            ),
            const SizedBox(height: 12),
            _HomeTile(
              title: 'Setlists',
              subtitle: 'Upcoming services',
              icon: Icons.queue_music_outlined,
              accent: Sanctuary.auroraCyan,
              onTap: () => context.push('/setlists'),
            ),
            const SizedBox(height: 12),
            _HomeTile(
              title: 'Schedule',
              subtitle: 'Sunday roster',
              icon: Icons.calendar_month_outlined,
              accent: Sanctuary.auroraMagenta,
              onTap: () => context.push('/schedule'),
            ),
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

/// One-tap enrollment card for biometric unlock. Hides itself if the device
/// has no biometric support, OR if the user has already enabled it.
class _BiometricToggle extends ConsumerStatefulWidget {
  const _BiometricToggle();

  @override
  ConsumerState<_BiometricToggle> createState() => _BiometricToggleState();
}

class _BiometricToggleState extends ConsumerState<_BiometricToggle> {
  bool? _canCheck;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _probe();
  }

  Future<void> _probe() async {
    final svc = ref.read(biometricServiceProvider);
    final can = await svc?.canCheckBiometrics() ?? false;
    if (mounted) setState(() => _canCheck = can);
  }

  Future<void> _enable() async {
    final svc = ref.read(biometricServiceProvider);
    if (svc == null || _busy) return;
    setState(() => _busy = true);
    final ok = await svc.authenticate(
      reason: 'Enable biometric unlock for Worship Hub',
    );
    if (!mounted) return;
    if (ok) {
      await svc.setEnabled(true);
      ref.read(unlockSessionProvider.notifier).unlock();
    }
    setState(() => _busy = false);
  }

  Future<void> _disable() async {
    final svc = ref.read(biometricServiceProvider);
    await svc?.setEnabled(false);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final svc = ref.watch(biometricServiceProvider);
    if (svc == null || _canCheck != true) return const SizedBox.shrink();

    final enabled = svc.isEnabled;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: Sanctuary.glass1,
        border: Border.all(color: Sanctuary.hairline),
        borderRadius: BorderRadius.circular(Sanctuary.radiusLg),
      ),
      child: Row(
        children: [
          Icon(
            Icons.fingerprint,
            size: 22,
            color: enabled ? Sanctuary.auroraCyan : Sanctuary.muted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Biometric unlock',
                  style: Sanctuary.display(fontSize: 14),
                ),
                Text(
                  enabled
                      ? 'On · ask each time the app opens'
                      : 'Off · use fingerprint or face',
                  style: const TextStyle(
                    color: Sanctuary.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: enabled,
            onChanged: _busy
                ? null
                : (v) {
                    if (v) {
                      _enable();
                    } else {
                      _disable();
                    }
                  },
            activeThumbColor: Sanctuary.auroraCyan,
          ),
        ],
      ),
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
