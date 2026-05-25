import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../../data/sync/sync_service.dart';

class SetlistComposeScreen extends ConsumerStatefulWidget {
  const SetlistComposeScreen({super.key});

  @override
  ConsumerState<SetlistComposeScreen> createState() =>
      _SetlistComposeScreenState();
}

class _SetlistComposeScreenState extends ConsumerState<SetlistComposeScreen> {
  final _theme = TextEditingController();
  final _notes = TextEditingController();
  DateTime _date = _nextSunday();
  bool _busy = false;
  String? _error;

  static DateTime _nextSunday() {
    final now = DateTime.now();
    final dow = now.weekday; // Mon=1 .. Sun=7
    final daysAhead = dow == 7 ? 7 : 7 - dow;
    final s = now.add(Duration(days: daysAhead));
    return DateTime(s.year, s.month, s.day);
  }

  @override
  void dispose() {
    _theme.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final id = await ref.read(syncServiceProvider).createSetlist(
          serviceDate: _date,
          theme: _theme.text.trim(),
          notes: _notes.text.trim(),
        );
    if (!mounted) return;
    if (id != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Setlist created.')),
      );
      context.go('/setlists/$id');
    } else {
      setState(() {
        _busy = false;
        _error = 'Could not create. Check connection or leader role.';
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
              context.canPop() ? context.pop() : context.go('/setlists'),
        ),
        title: const Text('New setlist'),
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
                  Text('SERVICE DATE', style: Sanctuary.mono(fontSize: 10)),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(Sanctuary.radiusMd),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: Sanctuary.glass1,
                        border: Border.all(color: Sanctuary.hairline),
                        borderRadius: BorderRadius.circular(Sanctuary.radiusMd),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined,
                              size: 18, color: Sanctuary.auroraCyan),
                          const SizedBox(width: 10),
                          Text(
                            DateFormat('EEEE, MMM d, y').format(_date),
                            style: const TextStyle(
                                color: Sanctuary.foreground, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _theme,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Theme (optional, e.g. "Easter")',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notes,
                    minLines: 3,
                    maxLines: 8,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Notes for the team (optional)',
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
                        : const Text('Create setlist'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Add songs after creating — opens the song picker on the next screen.',
              style: TextStyle(color: Sanctuary.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
