import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../../data/sync/sync_service.dart';

class SetlistComposeScreen extends ConsumerStatefulWidget {
  const SetlistComposeScreen({super.key, this.setlistId});

  /// When set, edit this existing setlist instead of creating a new one.
  final String? setlistId;

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

  bool get _isEditing => widget.setlistId != null;

  static DateTime _nextSunday() {
    final now = DateTime.now();
    final dow = now.weekday; // Mon=1 .. Sun=7
    final daysAhead = dow == 7 ? 7 : 7 - dow;
    final s = now.add(Duration(days: daysAhead));
    return DateTime(s.year, s.month, s.day);
  }

  @override
  void initState() {
    super.initState();
    if (_isEditing) _loadExisting();
  }

  Future<void> _loadExisting() async {
    final existing =
        await ref.read(appDbProvider).watchSetlist(widget.setlistId!).first;
    if (existing == null || !mounted) return;
    setState(() {
      _date = existing.serviceDate;
      _theme.text = existing.theme ?? '';
      _notes.text = existing.notes ?? '';
    });
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
    final svc = ref.read(syncServiceProvider);
    if (_isEditing) {
      final ok = await svc.updateSetlist(
        id: widget.setlistId!,
        serviceDate: _date,
        theme: _theme.text.trim(),
        notes: _notes.text.trim(),
      );
      if (!mounted) return;
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Setlist updated.')),
        );
        context.go('/setlists/${widget.setlistId}');
      } else {
        setState(() {
          _busy = false;
          _error = 'Could not save. Check connection or leader role.';
        });
      }
      return;
    }
    final id = await svc.createSetlist(
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
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 20),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/setlists'),
        ),
        title: Text(_isEditing ? 'Edit setlist' : 'New setlist'),
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
                  Text('SERVICE DATE',
                      style: Sanctuary.mono(
                          fontSize: 10, color: cs.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(Sanctuary.radiusMd),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Sanctuary.glass1
                            : Sanctuary.lightGlass1,
                        border: Border.all(color: cs.outlineVariant),
                        borderRadius: BorderRadius.circular(Sanctuary.radiusMd),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_outlined,
                              size: 18, color: cs.secondary),
                          const SizedBox(width: 10),
                          Text(
                            DateFormat('EEEE, MMM d, y').format(_date),
                            style: TextStyle(
                                color: cs.onSurface, fontSize: 14),
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
                        style: TextStyle(color: cs.error, fontSize: 13)),
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
                        : Text(_isEditing ? 'Save changes' : 'Create setlist'),
                  ),
                ],
              ),
            ),
            if (!_isEditing) ...[
              const SizedBox(height: 12),
              Text(
                'Add songs after creating — opens the song picker on the next screen.',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
