import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../data/sync/sync_service.dart';

class DevotionComposeScreen extends ConsumerStatefulWidget {
  const DevotionComposeScreen({super.key});

  @override
  ConsumerState<DevotionComposeScreen> createState() =>
      _DevotionComposeScreenState();
}

class _DevotionComposeScreenState
    extends ConsumerState<DevotionComposeScreen> {
  final _title = TextEditingController();
  final _scripture = TextEditingController();
  final _body = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _scripture.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _title.text.trim();
    final body = _body.text.trim();
    if (title.isEmpty || body.isEmpty) {
      setState(() => _error = 'Title and body are required.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final id = await ref.read(syncServiceProvider).postDevotion(
          title: title,
          body: body,
          scriptureRef: _scripture.text.trim(),
        );
    if (!mounted) return;
    if (id != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Devotion published.')),
      );
      context.pop();
    } else {
      setState(() {
        _busy = false;
        _error = 'Could not publish. Check your connection or leader role.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 20),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/devotions'),
        ),
        title: const Text('New devotion'),
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
                  TextField(
                    controller: _title,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(hintText: 'Title'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _scripture,
                    decoration: const InputDecoration(
                      hintText: 'Scripture reference (e.g. Psalm 23:1-4)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _body,
                    minLines: 8,
                    maxLines: 18,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Body (markdown supported)',
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(_error!,
                        style: const TextStyle(
                            color: Sanctuary.destructive, fontSize: 13)),
                  ],
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Publish'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
