import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase_client.dart';
import '../../../core/theme.dart';
import '../auth_errors.dart';
import '../biometric_service.dart';

/// Card-style toggle that surfaces the device's biometric (fingerprint /
/// face) enrolment status for sign-in. Hides itself when the device has
/// no biometric hardware available.
///
/// Originally lived on the home screen — moved to its own file so the
/// settings/profile screen can render the same control.
class BiometricToggle extends ConsumerStatefulWidget {
  const BiometricToggle({super.key});

  @override
  ConsumerState<BiometricToggle> createState() => _BiometricToggleState();
}

class _BiometricToggleState extends ConsumerState<BiometricToggle> {
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

  /// Re-validates the password against Supabase, then stores it encrypted
  /// alongside the email so future sign-ins can skip the keyboard.
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
      await supabase.auth
          .signInWithPassword(email: email, password: password)
          .timeout(const Duration(seconds: 10));
      if (!mounted) return;
      final authed = await svc.authenticate(
        reason: 'Verify to enable fingerprint sign-in',
      );
      if (!authed) return;
      await svc.enrollWithCredentials(
        email: email,
        password: password,
        userId: supabase.auth.currentUser?.id,
      );
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
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final svc = ref.watch(biometricServiceProvider);
    if (svc == null || _canCheck != true) return const SizedBox.shrink();

    final enabled = svc.isEnabled;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: isDark ? Sanctuary.glass1 : Sanctuary.lightGlass1,
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(Sanctuary.radiusLg),
      ),
      child: Row(
        children: [
          Icon(
            Icons.fingerprint,
            size: 22,
            color: enabled ? cs.secondary : cs.onSurfaceVariant,
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
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (enabled)
            TextButton(
              onPressed: _busy ? null : _disable,
              child: Text(
                'Disable',
                style: TextStyle(color: cs.error),
              ),
            )
          else
            TextButton(
              onPressed: _busy ? null : _enrol,
              child: _busy
                  ? SizedBox(
                      height: 14,
                      width: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cs.secondary,
                      ),
                    )
                  : Text(
                      'Set up',
                      style: TextStyle(color: cs.secondary),
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
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      backgroundColor: cs.surfaceContainerHigh,
      title: const Text('Enter your password'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Confirm your password to enable fingerprint sign-in. We\'ll '
            'store it encrypted on this device only.',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
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
