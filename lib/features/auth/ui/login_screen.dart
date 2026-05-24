import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_client.dart';
import '../../../core/theme.dart';

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

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await supabase.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
                  const _BrandMark(size: 64),
                  const SizedBox(height: 16),
                  Text('Worship Hub', style: Sanctuary.display(fontSize: 28)),
                  const SizedBox(height: 4),
                  Text('Worship · Team · Hub',
                      style: Sanctuary.mono(fontSize: 11)),
                  const SizedBox(height: 32),
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
                          decoration:
                              const InputDecoration(hintText: 'Password'),
                          onSubmitted: (_) => _signIn(),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(_error!,
                              style: const TextStyle(
                                  color: Sanctuary.destructive, fontSize: 13)),
                        ],
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _busy ? null : _signIn,
                          child: _busy
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Text('Sign in'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Create an account on the web app, then sign in here.',
                    style: TextStyle(
                        color: Sanctuary.muted.withValues(alpha: 0.8),
                        fontSize: 12),
                    textAlign: TextAlign.center,
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

class _BrandMark extends StatelessWidget {
  const _BrandMark({this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.18),
        gradient: const SweepGradient(
          startAngle: 2.4,
          colors: [
            Sanctuary.auroraCyan,
            Sanctuary.auroraViolet,
            Sanctuary.auroraMagenta,
            Sanctuary.auroraCyan,
          ],
        ),
      ),
      child: Center(
        child: Container(
          width: size * 0.65,
          height: size * 0.65,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.12),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Sanctuary.auroraCyan, Sanctuary.auroraViolet],
            ),
          ),
        ),
      ),
    );
  }
}
