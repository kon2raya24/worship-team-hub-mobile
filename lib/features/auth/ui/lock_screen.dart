import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../biometric_service.dart';

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  bool _trying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryUnlock());
  }

  Future<void> _tryUnlock() async {
    final svc = ref.read(biometricServiceProvider);
    if (svc == null || _trying) return;
    setState(() {
      _trying = true;
      _error = null;
    });
    final ok = await svc.authenticate(reason: 'Unlock Worship Hub');
    if (!mounted) return;
    if (ok) {
      ref.read(unlockSessionProvider.notifier).unlock();
      context.go('/');
    } else {
      setState(() {
        _trying = false;
        _error = 'Authentication cancelled.';
      });
    }
  }

  Future<void> _signOut() async {
    final svc = ref.read(biometricServiceProvider);
    await svc?.signOutAndDisable();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    gradient: const SweepGradient(
                      colors: [
                        Sanctuary.auroraCyan,
                        Sanctuary.auroraViolet,
                        Sanctuary.auroraMagenta,
                        Sanctuary.auroraCyan,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Container(
                    margin: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Sanctuary.ink1,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.fingerprint,
                      size: 44,
                      color: Sanctuary.auroraCyan,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Locked',
                  style: Sanctuary.display(fontSize: 28),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Verify it\'s you to continue.',
                  style: TextStyle(color: Sanctuary.muted, fontSize: 14),
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
                const SizedBox(height: 28),
                ElevatedButton.icon(
                  onPressed: _trying ? null : _tryUnlock,
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('Unlock'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Sanctuary.auroraViolet,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _signOut,
                  child: const Text(
                    'Sign in with password instead',
                    style: TextStyle(color: Sanctuary.muted, fontSize: 13),
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
