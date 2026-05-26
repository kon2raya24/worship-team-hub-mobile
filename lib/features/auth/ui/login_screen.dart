import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthException, AuthRetryableFetchException;

import '../../../core/supabase_client.dart';
import '../../../core/theme.dart';
import '../../../data/sync/connectivity.dart';
import '../auth_errors.dart';
import '../auth_provider.dart';
import '../biometric_service.dart';
import 'brand_mark.dart';

const _kRememberMeKey = 'remember_me';
const _kRememberedEmailKey = 'remembered_email';
const _kSignInTimeout = Duration(seconds: 10);

/// True for errors that look like the device just can't reach Supabase
/// (vs. a real auth rejection). Used to decide whether to fall back to the
/// stored-credentials offline path.
bool _isNetworkError(Object e) {
  // supabase_flutter v2 throws this for any network-layer failure. Catch
  // it by type so we don't depend on the message text.
  if (e is AuthRetryableFetchException) return true;
  if (e is TimeoutException) return true;
  bool looksNetwork(String s) =>
      s.contains('failed host lookup') ||
      s.contains('network is unreachable') ||
      s.contains('socketexception') ||
      s.contains('connection refused') ||
      s.contains('connection closed') ||
      s.contains('connection reset') ||
      s.contains('timeoutexception') ||
      s.contains('clientexception') ||
      s.contains('handshakeexception');
  if (e is AuthException && looksNetwork(e.message.toLowerCase())) return true;
  return looksNetwork(e.toString().toLowerCase());
}

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
    // SharedPreferences resolves asynchronously. If we read the service
    // before it's ready, we get null — and on cold start that lands us in
    // a state where the biometric button never appears. Wait for prefs
    // first so the provider has a real BiometricService to hand back.
    await ref.read(sharedPrefsProvider.future);
    if (!mounted) return;
    final svc = ref.read(biometricServiceProvider);
    if (svc == null) return;
    final can = await svc.canCheckBiometrics();
    final hasCreds = await svc.hasStoredCredentials();
    // Clean up a stale "enabled" flag from older versions where we set
    // the flag without actually saving credentials.
    if (svc.isEnabled && !hasCreds) {
      await svc.disable();
    }
    if (mounted) {
      setState(() {
        _canCheckBiometrics = can;
        _hasStoredCredentials = hasCreds;
      });
    }
  }

  /// Best-effort current connectivity: prefer the cached stream value, fall
  /// back to a direct probe (the stream's first emit may not have landed yet
  /// on cold start). Returns null only if both paths failed.
  Future<List<ConnectivityResult>?> _currentConnectivity() async {
    final cached = ref.read(connectivityProvider).value;
    if (cached != null) return cached;
    try {
      return await Connectivity().checkConnectivity();
    } catch (_) {
      return null;
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

    final svc = ref.read(biometricServiceProvider);
    final connectivity = await _currentConnectivity();
    final knownOffline = connectivity != null && !isOnline(connectivity);

    // Fast path: connectivity says we're offline. Skip the network call
    // entirely and try to verify against the last-signed-in credentials.
    if (knownOffline) {
      final ok = await _tryOfflineSignIn(svc, email, password);
      if (!mounted) return;
      if (!ok) {
        setState(() {
          _busy = false;
          _error =
              "You're offline. Use the email and password you last signed in with on this device.";
        });
      }
      return;
    }

    try {
      await supabase.auth
          .signInWithPassword(email: email, password: password)
          .timeout(_kSignInTimeout);
      // Real session restored — leave offline mode if we were in it.
      ref.read(offlineModeProvider.notifier).state = false;
      await _persistRememberMe(email);
      if (svc != null) {
        if (_rememberMe) {
          await svc.rememberCredentials(
            email: email,
            password: password,
            userId: supabase.auth.currentUser?.id,
          );
        } else {
          // User opted out — forget any stored creds and disable biometric
          // (biometric can't sign in without the password).
          await svc.disable();
          if (mounted) setState(() => _hasStoredCredentials = false);
        }
      }
      if (!mounted) return;
      await _offerBiometricEnrollment(email, password);
    } catch (e) {
      // If the failure is network-shaped, try the offline path with the
      // typed credentials. Real auth failures (bad password) fall through
      // and show the friendly error.
      if (_isNetworkError(e)) {
        final ok = await _tryOfflineSignIn(svc, email, password);
        if (!mounted) return;
        if (ok) return;
      }
      if (mounted) setState(() => _error = friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Verify typed creds against secure-storage and, on match, enter offline
  /// mode + navigate home. Returns true if we successfully signed the user
  /// in offline.
  Future<bool> _tryOfflineSignIn(
    BiometricService? svc,
    String email,
    String password,
  ) async {
    if (svc == null) return false;
    final matched = await svc.verifyStoredCredentials(
      email: email,
      password: password,
    );
    if (!matched) return false;
    ref.read(offlineModeProvider.notifier).state = true;
    await _persistRememberMe(email);
    // The router watches effectiveSignedInProvider, so toggling offline mode
    // auto-redirects to '/' — no manual context.go needed.
    return true;
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
    // Fast path: if we know we're offline, skip the network call entirely.
    // The biometric prompt has already proved who the user is. Toggling
    // offline mode is enough — the router auto-redirects to '/'.
    final connectivity = await _currentConnectivity();
    if (connectivity != null && !isOnline(connectivity)) {
      ref.read(offlineModeProvider.notifier).state = true;
      if (mounted) setState(() => _busy = false);
      return;
    }
    try {
      await supabase.auth
          .signInWithPassword(
            email: creds.email,
            password: creds.password,
          )
          .timeout(_kSignInTimeout);
    } catch (e) {
      // The biometric already proved who the user is. If the failure looks
      // like a network problem, drop into offline mode so the user can still
      // read cached data. A real AuthException (credentials changed
      // online) means we need a fresh password.
      if (_isNetworkError(e) && mounted) {
        ref.read(offlineModeProvider.notifier).state = true;
        // Router watches effectiveSignedInProvider — it will redirect us.
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

  // SharedPreferences flag — true once the user has been offered the
  // biometric enrolment prompt at least once. Prevents nagging on every
  // successful sign-in if they tap "Not now". Re-prompts only via the
  // explicit "Set up" control on Settings.
  static const _biometricPromptSeenKey = 'biometric_prompt_seen';

  Future<void> _offerBiometricEnrollment(String email, String password) async {
    final svc = ref.read(biometricServiceProvider);
    if (svc == null || !_canCheckBiometrics) return;
    // Already enrolled — nothing to offer.
    final alreadyEnrolled = svc.isEnabled && await svc.hasStoredCredentials();
    if (alreadyEnrolled) return;
    // One-time prompt: skip if the user already saw + dismissed it.
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_biometricPromptSeenKey) == true) return;
    if (!mounted) return;
    final shouldEnable = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Sanctuary.ink2,
        title: const Text('Enable fingerprint sign-in?'),
        content: const Text(
          'Sign in next time with your fingerprint. Your credentials are stored '
          'encrypted on this device only. You can change this later in Settings.',
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
    // Mark seen regardless of choice — they made one, don't ask again.
    await prefs.setBool(_biometricPromptSeenKey, true);
    if (shouldEnable != true) return;
    final authed = await svc.authenticate(reason: 'Verify to enable biometrics');
    if (authed) {
      await svc.enrollWithCredentials(
        email: email,
        password: password,
        userId: supabase.auth.currentUser?.id,
      );
      if (mounted) setState(() => _hasStoredCredentials = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final svc = ref.watch(biometricServiceProvider);
    // Only show the biometric button when the user has explicitly enrolled
    // biometric AND creds are present. "Remember me" alone (creds stored,
    // biometric disabled) keeps the password-only sign-in flow.
    final showBiometric = svc != null &&
        _canCheckBiometrics &&
        svc.isEnabled &&
        _hasStoredCredentials;

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
                          autocorrect: false,
                          textCapitalization: TextCapitalization.none,
                          decoration: const InputDecoration(hintText: 'Email'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _password,
                          obscureText: true,
                          autofillHints: const [AutofillHints.password],
                          autocorrect: false,
                          enableSuggestions: false,
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
