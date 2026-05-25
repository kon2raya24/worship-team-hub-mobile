import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/supabase_client.dart';
import '../../../core/theme.dart';
import '../../../data/sync/sync_service.dart';
import '../../auth/auth_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _name = TextEditingController();
  final _instruments = TextEditingController();
  bool _busy = false;
  bool _hydrated = false;
  String? _info;
  String? _error;

  @override
  void initState() {
    super.initState();
    _hydrate();
  }

  Future<void> _hydrate() async {
    final p = await ref.read(currentProfileProvider.future);
    if (!mounted) return;
    if (p != null) {
      _name.text = p.displayName;
    }
    setState(() => _hydrated = true);
  }

  @override
  void dispose() {
    _name.dispose();
    _instruments.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Display name is required.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    final instruments = _instruments.text
        .split(RegExp(r'[,\s]+'))
        .where((t) => t.isNotEmpty)
        .toList();
    final ok = await ref.read(syncServiceProvider).updateMyProfile(
          displayName: name,
          instruments: instruments.isEmpty ? null : instruments,
        );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _info = ok ? 'Profile updated.' : null;
      _error = ok ? null : 'Could not save. Check your connection.';
    });
    if (ok) ref.invalidate(currentProfileProvider);
  }

  @override
  Widget build(BuildContext context) {
    final email = supabase.auth.currentUser?.email ?? '';
    if (!_hydrated) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 20),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: const Text('Settings'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('ACCOUNT', style: Sanctuary.mono(fontSize: 10)),
                  const SizedBox(height: 8),
                  Text(email,
                      style: const TextStyle(
                          color: Sanctuary.muted, fontSize: 13)),
                  const SizedBox(height: 16),
                  Text('DISPLAY NAME', style: Sanctuary.mono(fontSize: 10)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(hintText: 'Your name'),
                  ),
                  const SizedBox(height: 12),
                  Text('INSTRUMENTS', style: Sanctuary.mono(fontSize: 10)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _instruments,
                    decoration: const InputDecoration(
                      hintText: 'vocals, acoustic, drums (comma-separated)',
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(_error!,
                        style: const TextStyle(
                            color: Sanctuary.destructive, fontSize: 13)),
                  ],
                  if (_info != null) ...[
                    const SizedBox(height: 10),
                    Text(_info!,
                        style: const TextStyle(
                            color: Sanctuary.success, fontSize: 13)),
                  ],
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: _busy ? null : _save,
                    child: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Save changes'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Password and email changes happen on the web app for now.',
              style: TextStyle(color: Sanctuary.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
