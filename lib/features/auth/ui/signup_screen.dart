import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/supabase_client.dart';
import '../../../core/theme.dart';
import '../auth_errors.dart';
import 'brand_mark.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    final name = _name.text.trim();
    final email = _email.text.trim();
    final password = _password.text;
    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() => _error = 'All fields are required.');
      return;
    }
    if (password.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      final res = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {'display_name': name},
      );
      if (!mounted) return;
      // If Supabase requires email confirmation, session will be null.
      if (res.session == null) {
        setState(() {
          _info =
              'Check your email to confirm your account, then sign in.';
        });
      } else {
        // Signed in automatically — router redirect lands on /
        context.go('/');
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 20),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/login'),
        ),
        title: const Text('Create account'),
      ),
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
                  Text(
                    'Join your team',
                    style: Sanctuary.display(fontSize: 24),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your leader can promote your role once you\'re in.',
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _name,
                          textCapitalization: TextCapitalization.words,
                          autofillHints: const [AutofillHints.name],
                          decoration: const InputDecoration(
                            hintText: 'Display name',
                          ),
                        ),
                        const SizedBox(height: 12),
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
                          autofillHints: const [AutofillHints.newPassword],
                          decoration: const InputDecoration(
                            hintText: 'Password (8+ characters)',
                          ),
                          onSubmitted: (_) => _signUp(),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            style: TextStyle(
                              color: cs.error,
                              fontSize: 13,
                            ),
                          ),
                        ],
                        if (_info != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _info!,
                            style: TextStyle(
                              color: cs.secondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _busy ? null : _signUp,
                          child: _busy
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Create account'),
                        ),
                      ],
                    ),
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
