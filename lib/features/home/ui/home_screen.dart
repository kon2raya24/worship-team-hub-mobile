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
import '../../auth/auth_provider.dart';
import '../../auth/biometric_service.dart';

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
    final email = currentUser?.email ?? '';
    final greetTarget = name.isNotEmpty
        ? name
        : email.isNotEmpty
            ? email.split('@').first
            : 'team';
    final offline = ref.watch(offlineModeProvider);
    // Fire-and-forget initial sync. Errors are surfaced via the badge below.
    final sync = offline ? const AsyncValue<SyncResult>.data(SyncResult.skipped)
        : ref.watch(startupSyncProvider);
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
            Text('SIGNED IN AS', style: Sanctuary.mono(fontSize: 10)),
            const SizedBox(height: 2),
            Text(
              greetTarget,
              style: Sanctuary.mono(
                fontSize: 12,
                color: Sanctuary.foreground,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.05,
              ),
            ),
            const SizedBox(height: 8),
            Text('Welcome back', style: Sanctuary.display(fontSize: 26)),
            const SizedBox(height: 10),
            if (offline)
              _OfflineBanner()
            else
              _SyncBadge(state: sync, online: online),
            const SizedBox(height: 14),
            const _BiometricToggle(),
            const SizedBox(height: 20),

            // Two-column tile grid — feels denser on phones and lets us
            // surface every module without an endless vertical scroll.
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.08,
              children: const [
                _HomeTile(
                  title: 'Songs',
                  subtitle: 'Chord charts',
                  icon: Icons.library_music_outlined,
                  accent: Sanctuary.auroraViolet,
                  path: '/songs',
                ),
                _HomeTile(
                  title: 'Setlists',
                  subtitle: 'Sunday plans',
                  icon: Icons.queue_music_outlined,
                  accent: Sanctuary.auroraCyan,
                  path: '/setlists',
                ),
                _HomeTile(
                  title: 'Schedule',
                  subtitle: 'Team roster',
                  icon: Icons.calendar_month_outlined,
                  accent: Sanctuary.auroraMagenta,
                  path: '/schedule',
                ),
                _HomeTile(
                  title: 'Devotions',
                  subtitle: 'Weekly reflections',
                  icon: Icons.menu_book_outlined,
                  accent: Sanctuary.auroraAmber,
                  path: '/devotions',
                ),
                _HomeTile(
                  title: 'Prayer',
                  subtitle: 'Requests + answered',
                  icon: Icons.favorite_outline,
                  accent: Sanctuary.auroraMagenta,
                  path: '/prayer',
                ),
                _HomeTile(
                  title: 'Announcements',
                  subtitle: 'Team updates',
                  icon: Icons.campaign_outlined,
                  accent: Sanctuary.auroraCyan,
                  path: '/announcements',
                ),
                _HomeTile(
                  title: 'Games',
                  subtitle: 'Music drills',
                  icon: Icons.sports_esports_outlined,
                  accent: Sanctuary.auroraViolet,
                  path: '/games',
                ),
              ],
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
    required this.path,
  });

  final String title;
  final String subtitle;
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
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accent.withValues(alpha: 0.07),
                Sanctuary.glass1,
              ],
            ),
            border: Border.all(color: accent.withValues(alpha: 0.18)),
            borderRadius: BorderRadius.circular(Sanctuary.radiusLg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  border: Border.all(color: accent.withValues(alpha: 0.35)),
                  borderRadius: BorderRadius.circular(Sanctuary.radiusMd),
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              const Spacer(),
              Text(
                title,
                style: Sanctuary.display(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Sanctuary.muted,
                  fontSize: 11.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
