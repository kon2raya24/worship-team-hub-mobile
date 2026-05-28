import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_client.dart';
import '../../../core/theme.dart';

enum _Status { loading, off, enrolling, on }

/// Opt-in TOTP two-factor auth for the Settings screen, mirroring the web
/// app: enroll shows a QR + secret to scan, a code verifies the factor; once
/// on, a Disable button unenrolls.
class TwoFactorSection extends ConsumerStatefulWidget {
  const TwoFactorSection({super.key});

  @override
  ConsumerState<TwoFactorSection> createState() => _TwoFactorSectionState();
}

class _TwoFactorSectionState extends ConsumerState<TwoFactorSection> {
  _Status _status = _Status.loading;
  String? _factorId;
  String? _qrSvg;
  String? _secret;
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final res = await supabase.auth.mfa.listFactors();
      final verified =
          res.totp.where((f) => f.status == FactorStatus.verified).toList();
      if (!mounted) return;
      setState(() {
        if (verified.isNotEmpty) {
          _factorId = verified.first.id;
          _status = _Status.on;
        } else {
          _status = _Status.off;
        }
      });
    } catch (_) {
      if (mounted) setState(() => _status = _Status.off);
    }
  }

  Future<void> _startEnroll() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Clear stale half-finished factors so enroll doesn't collide.
      final existing = await supabase.auth.mfa.listFactors();
      for (final f in existing.all) {
        if (f.status == FactorStatus.unverified) {
          await supabase.auth.mfa.unenroll(f.id);
        }
      }
      final res = await supabase.auth.mfa.enroll(factorType: FactorType.totp);
      if (!mounted) return;
      final totp = res.totp;
      if (totp == null) {
        setState(() {
          _busy = false;
          _error = "Couldn't start setup. Try again.";
        });
        return;
      }
      setState(() {
        _factorId = res.id;
        _qrSvg = totp.qrCode;
        _secret = totp.secret;
        _status = _Status.enrolling;
        _busy = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = "Couldn't start setup. Try again.";
        });
      }
    }
  }

  Future<void> _verifyEnroll() async {
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
      if (!mounted) return;
      setState(() {
        _qrSvg = null;
        _secret = null;
        _code.clear();
        _status = _Status.on;
        _busy = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = "That code didn't match. Check your app and try again.";
        });
      }
    }
  }

  Future<void> _disable() async {
    final fid = _factorId;
    if (fid == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await supabase.auth.mfa.unenroll(fid);
      if (!mounted) return;
      setState(() {
        _factorId = null;
        _status = _Status.off;
        _busy = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = "Couldn't disable. Try again.";
        });
      }
    }
  }

  void _cancelEnroll() {
    final fid = _factorId;
    if (fid != null) supabase.auth.mfa.unenroll(fid);
    setState(() {
      _qrSvg = null;
      _secret = null;
      _code.clear();
      _factorId = null;
      _error = null;
      _status = _Status.off;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined,
                  size: 16, color: Sanctuary.success),
              const SizedBox(width: 8),
              Text('TWO-FACTOR', style: Sanctuary.mono(fontSize: 10)),
            ],
          ),
          const SizedBox(height: 10),
          ..._body(),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!,
                style: const TextStyle(
                    color: Sanctuary.destructive, fontSize: 13)),
          ],
        ],
      ),
    );
  }

  List<Widget> _body() {
    switch (_status) {
      case _Status.loading:
        return const [
          SizedBox(
            height: 28,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        ];
      case _Status.off:
        return [
          const Text(
            'Add a code step at sign-in with an authenticator app '
            '(Google Authenticator, Authy, 1Password).',
            style: TextStyle(color: Sanctuary.muted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy ? null : _startEnroll,
            child: _busy
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Enable 2FA'),
          ),
        ];
      case _Status.enrolling:
        return [
          const Text(
            'Scan this in your authenticator app, then enter the 6-digit code.',
            style: TextStyle(color: Sanctuary.muted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          if (_qrSvg != null)
            Center(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(Sanctuary.radiusMd),
                ),
                child: SvgPicture.string(_qrSvg!, width: 168, height: 168),
              ),
            ),
          if (_secret != null) ...[
            const SizedBox(height: 12),
            const Text('Or enter this key manually:',
                style: TextStyle(color: Sanctuary.muted, fontSize: 11)),
            const SizedBox(height: 4),
            SelectableText(
              _secret!,
              style: Sanctuary.mono(
                  fontSize: 12, color: Sanctuary.foreground, letterSpacing: 1),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _code,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(
              hintText: '6-digit code',
              counterText: '',
            ),
            onSubmitted: (_) => _verifyEnroll(),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _busy ? null : _verifyEnroll,
                  child: _busy
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Verify & enable'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _busy ? null : _cancelEnroll,
                child: const Text('Cancel'),
              ),
            ],
          ),
        ];
      case _Status.on:
        return [
          Row(
            children: const [
              Icon(Icons.check_circle, size: 16, color: Sanctuary.success),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "2FA is on. You'll enter a code from your app at sign-in.",
                  style: TextStyle(color: Sanctuary.success, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : _disable,
            icon: _busy
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.shield_outlined, size: 16),
            label: const Text('Disable 2FA'),
          ),
        ];
    }
  }
}
