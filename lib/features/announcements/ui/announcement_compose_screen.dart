import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../data/sync/sync_service.dart';

class AnnouncementComposeScreen extends ConsumerStatefulWidget {
  const AnnouncementComposeScreen({super.key});

  @override
  ConsumerState<AnnouncementComposeScreen> createState() =>
      _AnnouncementComposeScreenState();
}

class _AnnouncementComposeScreenState
    extends ConsumerState<AnnouncementComposeScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  bool _pinned = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
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
    final id = await ref.read(syncServiceProvider).postAnnouncement(
          title: title,
          body: body,
          pinned: _pinned,
        );
    if (!mounted) return;
    if (id != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Announcement posted.')),
      );
      context.pop();
    } else {
      setState(() {
        _busy = false;
        _error = 'Could not post. Check your connection or leader role.';
      });
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
              context.canPop() ? context.pop() : context.go('/announcements'),
        ),
        title: const Text('New announcement'),
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
                    controller: _body,
                    minLines: 6,
                    maxLines: 14,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Body (markdown supported)',
                    ),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: Sanctuary.auroraAmber,
                    title: const Text('Pin to top'),
                    subtitle: Text(
                      'Pinned announcements appear above the rest until '
                      'unpinned.',
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                    ),
                    value: _pinned,
                    onChanged: (v) => setState(() => _pinned = v),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: cs.error,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Post'),
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
