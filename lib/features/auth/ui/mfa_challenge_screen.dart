import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_client.dart';
import '../../../core/theme.dart';
import '../auth_provider.dart';
import 'brand_mark.dart';

/// Shown after a password sign-in when the account has a verified TOTP factor
/// (the router redirects here while [mfaPendingProvider] is true). Verifying a
/// code elevates the session to AAL2 and clears the gate.
class MfaChallengeScreen extends ConsumerStatefulWidget {
  const MfaChallengeScreen({super.key});

  @override
  ConsumerState<MfaChallengeScreen> createState() => _MfaChallengeScreenState();
}

class _MfaChallengeScreenState extends ConsumerState<MfaChallengeScreen> {
  final _code = TextEditingController();
  String? _factorId;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFactor();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _loadFactor() async {
    try {
      final res = await supabase.auth.mfa.listFactors();
      final verified =
          res.totp.where((f) => f.status == FactorStatus.verified).toList();
      final factor = verified.isNotEmpty
          ? verified.first
          : (res.totp.isNotEmpty ? res.totp.first : null);
      if (!mounted) return;
      if (factor == null) {
        setState(() => _error = 'No 2FA factor found on this account.');
        return;
      }
      setState(() => _factorId = factor.id);
    } catch (_) {
      if (mounted) setState(() => _error = "Couldn't load your 2FA factor.");
    }
  }

  Future<void> _verify() async {
    final fid = _factorId;
    if (fid == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ch = await supabase.auth.mfa.challenge(factorId: fid);
      await supabase.auth.mfa
          .verify(factorId: fid, challengeId: ch.id, code: _code.text.trim());
      // Session is now AAL2 — drop the gate; the router redirects home.
      if (!mounted) return;
      ref.read(mfaPendingProvider.notifier).state = false;
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = "That code didn't match. Try again.";
        });
      }
    }
  }

  Future<void> _signOut() async {
    ref.read(mfaPendingProvider.notifier).state = false;
    await supabase.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
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
                  const BrandMark(size: 56),
                  const SizedBox(height: 16),
                  Text('Two-factor', style: Sanctuary.display(fontSize: 24)),
                  const SizedBox(height: 6),
                  const Text(
                    'Enter the 6-digit code from your authenticator app.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Sanctuary.muted, fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _code,
                          keyboardType: TextInputType.number,
                          autofocus: true,
                          maxLength: 6,
                          textAlign: TextAlign.center,
                          style: Sanctuary.mono(
                              fontSize: 22,
                              color: Sanctuary.foreground,
                              letterSpacing: 6),
                          decoration: const InputDecoration(
                            hintText: '123456',
                            counterText: '',
                          ),
                          onSubmitted: (_) => _verify(),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 10),
                          Text(_error!,
                              style: const TextStyle(
                                  color: Sanctuary.destructive, fontSize: 13)),
                        ],
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed:
                              _busy || _factorId == null ? null : _verify,
                          child: _busy
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Verify'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _busy ? null : _signOut,
                    child: const Text('Sign out',
                        style: TextStyle(
                            color: Sanctuary.muted, fontSize: 13)),
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
