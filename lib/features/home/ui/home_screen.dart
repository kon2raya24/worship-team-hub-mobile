import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/supabase_client.dart';
import '../../../core/theme.dart';
import '../../../data/sync/connectivity.dart';
import '../../../data/sync/providers.dart';
import '../../../data/sync/sync_service.dart';
import '../../auth/auth_errors.dart';
import '../../auth/biometric_service.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Sanctuary.ink2,
        title: const Text('Sign out?'),
        content: const Text(
          'You\'ll be returned to the login screen. Your offline cache and '
          'fingerprint enrolment stay on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Stay signed in'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Sanctuary.destructive,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
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
            onPressed: () => _signOut(context),
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
            const SizedBox(height: 12),
            _HomeTile(
              title: 'Devotions',
              subtitle: 'Weekly reflections',
              icon: Icons.menu_book_outlined,
              accent: Sanctuary.auroraAmber,
              onTap: () => context.push('/devotions'),
            ),
            const SizedBox(height: 12),
            _HomeTile(
              title: 'Prayer',
              subtitle: 'Requests + answered',
              icon: Icons.favorite_outline,
              accent: Sanctuary.auroraMagenta,
              onTap: () => context.push('/prayer'),
            ),
            const SizedBox(height: 12),
            _HomeTile(
              title: 'Announcements',
              subtitle: 'Team updates',
              icon: Icons.campaign_outlined,
              accent: Sanctuary.auroraCyan,
              onTap: () => context.push('/announcements'),
            ),
            const SizedBox(height: 12),
            _HomeTile(
              title: 'Games',
              subtitle: 'Music-theory warm-ups',
              icon: Icons.sports_esports_outlined,
              accent: Sanctuary.auroraViolet,
              onTap: () => context.push('/games'),
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

  Future<void> _disable() async {
    final svc = ref.read(biometricServiceProvider);
    await svc?.disable();
    if (mounted) setState(() {});
  }

  /// Enrol from the home screen after the user declined the post-login
  /// dialog. We need the password, so this opens a confirm dialog that
  /// re-validates the password against Supabase before storing.
  Future<void> _enrol() async {
    final svc = ref.read(biometricServiceProvider);
    final email = currentUser?.email;
    if (svc == null || email == null || _busy) return;

    final password = await showDialog<String?>(
      context: context,
      builder: (ctx) => const _PasswordConfirmDialog(),
    );
    if (password == null || password.isEmpty) return;

    setState(() => _busy = true);
    try {
      // Re-authenticate to confirm the password is correct before storing it.
      await supabase.auth.signInWithPassword(email: email, password: password);
      if (!mounted) return;
      final authed = await svc.authenticate(
        reason: 'Verify to enable fingerprint sign-in',
      );
      if (!authed) return;
      await svc.enrollWithCredentials(email: email, password: password);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fingerprint sign-in enabled.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyAuthError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
                      : 'Off · tap Set up to enrol now',
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
              onPressed: _busy ? null : _disable,
              child: const Text(
                'Disable',
                style: TextStyle(color: Sanctuary.destructive),
              ),
            )
          else
            TextButton(
              onPressed: _busy ? null : _enrol,
              child: _busy
                  ? const SizedBox(
                      height: 14,
                      width: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Sanctuary.auroraCyan,
                      ),
                    )
                  : const Text(
                      'Set up',
                      style: TextStyle(color: Sanctuary.auroraCyan),
                    ),
            ),
        ],
      ),
    );
  }
}

class _PasswordConfirmDialog extends StatefulWidget {
  const _PasswordConfirmDialog();

  @override
  State<_PasswordConfirmDialog> createState() => _PasswordConfirmDialogState();
}

class _PasswordConfirmDialogState extends State<_PasswordConfirmDialog> {
  final _controller = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Sanctuary.ink2,
      title: const Text('Enter your password'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Confirm your password to enable fingerprint sign-in. We\'ll '
            'store it encrypted on this device only.',
            style: TextStyle(color: Sanctuary.muted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            obscureText: _obscure,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Password',
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure ? Icons.visibility_off : Icons.visibility,
                  size: 18,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            onSubmitted: (v) => Navigator.of(context).pop(v),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Confirm'),
        ),
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
