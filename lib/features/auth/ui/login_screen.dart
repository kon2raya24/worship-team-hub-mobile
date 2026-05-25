import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/supabase_client.dart';
import '../../../core/theme.dart';
import '../auth_errors.dart';
import '../auth_provider.dart';
import '../biometric_service.dart';
import 'brand_mark.dart';

const _kRememberMeKey = 'remember_me';
const _kRememberedEmailKey = 'remembered_email';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;
  bool _canCheckBiometrics = false;
  bool _hasStoredCredentials = false;
  bool _rememberMe = true;

  @override
  void initState() {
    super.initState();
    _probeBiometric();
    _loadRememberedEmail();
  }

  Future<void> _loadRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final remember = prefs.getBool(_kRememberMeKey) ?? true;
    final email = prefs.getString(_kRememberedEmailKey);
    if (!mounted) return;
    setState(() {
      _rememberMe = remember;
      if (remember && email != null) _email.text = email;
    });
  }

  Future<void> _persistRememberMe(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kRememberMeKey, _rememberMe);
    if (_rememberMe) {
      await prefs.setString(_kRememberedEmailKey, email);
    } else {
      await prefs.remove(_kRememberedEmailKey);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _probeBiometric() async {
    final svc = ref.read(biometricServiceProvider);
    final can = await svc?.canCheckBiometrics() ?? false;
    final hasCreds = await svc?.hasStoredCredentials() ?? false;
    // Clean up a stale "enabled" flag from older versions where we set
    // the flag without actually saving credentials.
    if (svc != null && svc.isEnabled && !hasCreds) {
      await svc.disable();
    }
    if (mounted) {
      setState(() {
        _canCheckBiometrics = can;
        _hasStoredCredentials = hasCreds;
      });
    }
  }

  Future<void> _signInWithPassword() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Email and password are required.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await supabase.auth.signInWithPassword(email: email, password: password);
      // Real session restored — leave offline mode if we were in it.
      ref.read(offlineModeProvider.notifier).state = false;
      await _persistRememberMe(email);
      if (!mounted) return;
      await _offerBiometricEnrollment(email, password);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signInWithBiometric() async {
    final svc = ref.read(biometricServiceProvider);
    if (svc == null || !_hasStoredCredentials) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await svc.authenticate(reason: 'Sign in to Worship Hub');
    if (!ok) {
      if (mounted) setState(() => _busy = false);
      return;
    }
    final creds = await svc.readCredentials();
    if (creds == null) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'No saved credentials. Sign in with password to re-enrol.';
        });
        await svc.disable();
      }
      return;
    }
    try {
      await supabase.auth.signInWithPassword(
        email: creds.email,
        password: creds.password,
      );
    } catch (e) {
      // If the failure is a network issue, drop into offline mode using
      // the biometric-verified credentials. The cached Drift data is fully
      // readable; writes that hit Supabase will fail naturally.
      final s = e.toString().toLowerCase();
      final offline = s.contains('socketexception') ||
          s.contains('failed host lookup') ||
          s.contains('network is unreachable') ||
          s.contains('connection refused') ||
          s.contains('timeoutexception');
      if (offline) {
        ref.read(offlineModeProvider.notifier).state = true;
        // Router redirect will land on /
        return;
      }
      if (mounted) {
        setState(() {
          _error = '${friendlyAuthError(e)} Type your password to re-enrol.';
          _email.text = creds.email;
        });
        await svc.disable();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _offerBiometricEnrollment(String email, String password) async {
    final svc = ref.read(biometricServiceProvider);
    if (svc == null || !_canCheckBiometrics) return;
    // Offer if creds are not actually stored — even if a stale "enabled"
    // flag exists. That way users can recover from an older app version's
    // half-set state.
    final alreadyStored = await svc.hasStoredCredentials();
    if (alreadyStored) return;
    if (!mounted) return;
    final shouldEnable = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Sanctuary.ink2,
        title: const Text('Enable fingerprint sign-in?'),
        content: const Text(
          'Sign in next time with your fingerprint. Your credentials are stored '
          'encrypted on this device only.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Enable'),
          ),
        ],
      ),
    );
    if (shouldEnable != true) return;
    final authed = await svc.authenticate(reason: 'Verify to enable biometrics');
    if (authed) {
      await svc.enrollWithCredentials(email: email, password: password);
      if (mounted) setState(() => _hasStoredCredentials = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final svc = ref.watch(biometricServiceProvider);
    // Only show the biometric button when creds are actually stored.
    final showBiometric =
        svc != null && _canCheckBiometrics && _hasStoredCredentials;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const BrandMark(size: 64),
                  const SizedBox(height: 16),
                  Text('Worship Hub', style: Sanctuary.display(fontSize: 28)),
                  const SizedBox(height: 4),
                  Text(
                    'Worship · Team · Hub',
                    style: Sanctuary.mono(fontSize: 11),
                  ),
                  const SizedBox(height: 32),

                  if (showBiometric) ...[
                    _BiometricButton(busy: _busy, onTap: _signInWithBiometric),
                    const SizedBox(height: 14),
                    Row(
                      children: const [
                        Expanded(child: Divider(color: Sanctuary.hairline)),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'or',
                            style: TextStyle(
                              color: Sanctuary.muted,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: Sanctuary.hairline)),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ],

                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          decoration: const InputDecoration(hintText: 'Email'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _password,
                          obscureText: true,
                          autofillHints: const [AutofillHints.password],
                          decoration: const InputDecoration(
                            hintText: 'Password',
                          ),
                          onSubmitted: (_) => _signInWithPassword(),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            style: const TextStyle(
                              color: Sanctuary.destructive,
                              fontSize: 13,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            // Tap target for the checkbox + label together.
                            InkWell(
                              onTap: _busy
                                  ? null
                                  : () => setState(
                                        () => _rememberMe = !_rememberMe,
                                      ),
                              borderRadius: BorderRadius.circular(6),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                  horizontal: 2,
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: Checkbox(
                                        value: _rememberMe,
                                        onChanged: _busy
                                            ? null
                                            : (v) => setState(
                                                () => _rememberMe = v ?? false,
                                              ),
                                        materialTapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        visualDensity: VisualDensity.compact,
                                        activeColor: Sanctuary.auroraCyan,
                                        checkColor: Sanctuary.ink0,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Remember me',
                                      style: TextStyle(
                                        color: Sanctuary.muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => context.push('/forgot-password'),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                minimumSize: const Size(0, 32),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'Forgot password?',
                                style: TextStyle(
                                  color: Sanctuary.muted,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        FilledButton(
                          onPressed: _busy ? null : _signInWithPassword,
                          child: _busy
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Sign in'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'New here?',
                        style: TextStyle(
                          color: Sanctuary.muted.withValues(alpha: 0.8),
                          fontSize: 13,
                        ),
                      ),
                      TextButton(
                        onPressed: _busy ? null : () => context.push('/signup'),
                        child: const Text(
                          'Create an account',
                          style: TextStyle(
                            color: Sanctuary.auroraCyan,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BiometricButton extends StatelessWidget {
  const _BiometricButton({required this.busy, required this.onTap});
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(Sanctuary.radiusLg),
          onTap: busy ? null : onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Sanctuary.auroraCyan.withValues(alpha: 0.18),
                  Sanctuary.auroraViolet.withValues(alpha: 0.22),
                ],
              ),
              border: Border.all(
                color: Sanctuary.auroraCyan.withValues(alpha: 0.45),
              ),
              borderRadius: BorderRadius.circular(Sanctuary.radiusLg),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.fingerprint,
                  color: Sanctuary.auroraCyan,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  'Sign in with fingerprint',
                  style: Sanctuary.display(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
