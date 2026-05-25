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

  Future<void> _signOut() async {
    // NOTE: deliberately *not* clearing the biometric enrolment here. The
    // whole point of fingerprint sign-in is to skip the password on the
    // next launch — wiping it on every sign-out would defeat that. The
    // user can disable biometric explicitly from the home screen card.
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
            onPressed: _signOut,
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

/// Status card for biometric sign-in. Enrollment happens at the login screen
/// (we need the password to store), so this card only surfaces the current
/// state and offers a Disable action. Hidden if the device has no biometric
/// hardware.
class _BiometricToggle extends ConsumerStatefulWidget {
  const _BiometricToggle();

  @override
  ConsumerState<_BiometricToggle> createState() => _BiometricToggleState();
}

class _BiometricToggleState extends ConsumerState<_BiometricToggle> {
  bool? _canCheck;

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

  Future<void> _disable() async {
    final svc = ref.read(biometricServiceProvider);
    await svc?.disable();
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
                  'Fingerprint sign-in',
                  style: Sanctuary.display(fontSize: 14),
                ),
                Text(
                  enabled
                      ? 'On · skip the password on next sign-in'
                      : 'Off · enrol from the login screen after sign-in',
                  style: const TextStyle(
                    color: Sanctuary.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (enabled)
            TextButton(
              onPressed: _disable,
              child: const Text(
                'Disable',
                style: TextStyle(color: Sanctuary.destructive),
              ),
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
