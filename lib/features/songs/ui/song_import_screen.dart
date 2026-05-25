import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../data/sync/sync_service.dart';
import '../chordpro/chord_line_parse.dart';
import '../chordpro/chordpro_parse.dart';

class SongImportScreen extends ConsumerStatefulWidget {
  const SongImportScreen({super.key});

  @override
  ConsumerState<SongImportScreen> createState() => _SongImportScreenState();
}

class _SongImportScreenState extends ConsumerState<SongImportScreen> {
  final _input = TextEditingController();
  bool _autoConvert = true;
  bool _skipExisting = true;
  bool _busy = false;
  String? _info;
  String? _error;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    final raw = _input.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = 'Paste at least one song.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });

    final normalised = _autoConvert && looksLikeChordOverLyrics(raw)
        ? convertChordOverLyrics(raw)
        : raw;
    final blocks = splitChordProBlocks(normalised);
    final parsed = blocks
        .map(parseSingleChordPro)
        .where((p) => p.body.isNotEmpty)
        .toList();

    if (parsed.isEmpty) {
      setState(() {
        _busy = false;
        _error = 'Could not detect any songs in the paste.';
      });
      return;
    }
    final oversize = parsed.where(
      (p) => utf8.encode(p.body).length > maxChordProBytes,
    );
    if (oversize.isNotEmpty) {
      setState(() {
        _busy = false;
        _error =
            '"${oversize.first.title ?? "Untitled"}" is over the ${maxChordProBytes ~/ 1024} KB limit.';
      });
      return;
    }

    final rows = parsed
        .map((p) => {
              'title': (p.title ?? '').trim().isEmpty ? 'Untitled' : p.title!.trim(),
              if (p.artist != null) 'artist': p.artist,
              if (p.originalKey != null) 'original_key': p.originalKey,
              if (p.bpm != null) 'bpm': p.bpm,
              'chordpro_body': p.body,
              'tags': const ['imported'],
            })
        .toList();

    final result = await ref
        .read(syncServiceProvider)
        .bulkInsertSongs(rows, skipExisting: _skipExisting);
    if (!mounted) return;
    if (result == null) {
      setState(() {
        _busy = false;
        _error = 'Import failed. Check connection or leader role.';
      });
      return;
    }
    setState(() {
      _busy = false;
      _info = 'Added ${result.added} song${result.added == 1 ? "" : "s"}'
          '${result.skipped > 0 ? " · skipped ${result.skipped} duplicate${result.skipped == 1 ? "" : "s"}" : ""}.';
      if (result.added > 0) _input.clear();
    });
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
              context.canPop() ? context.pop() : context.go('/songs'),
        ),
        title: const Text('Bulk import'),
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
                  Text('PASTE', style: Sanctuary.mono(fontSize: 10)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _input,
                    minLines: 12,
                    maxLines: 24,
                    style: Sanctuary.mono(
                      fontSize: 12,
                      color: Sanctuary.foreground,
                      letterSpacing: 0,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Paste one or more songs.\n\n'
                          'Separate multiple songs with --- on its own line, '
                          'or just paste back-to-back {title: ...} blocks.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: Sanctuary.auroraCyan,
                    title: const Text('Auto-convert chord-over-lyrics'),
                    subtitle: const Text(
                      'Detects standalone chord lines and inlines them.',
                      style: TextStyle(color: Sanctuary.muted, fontSize: 12),
                    ),
                    value: _autoConvert,
                    onChanged: (v) => setState(() => _autoConvert = v),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: Sanctuary.auroraCyan,
                    title: const Text('Skip existing titles'),
                    subtitle: const Text(
                      'Case-insensitive match against songs already in the library.',
                      style: TextStyle(color: Sanctuary.muted, fontSize: 12),
                    ),
                    value: _skipExisting,
                    onChanged: (v) => setState(() => _skipExisting = v),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!,
                        style: const TextStyle(
                            color: Sanctuary.destructive, fontSize: 13)),
                  ],
                  if (_info != null) ...[
                    const SizedBox(height: 8),
                    Text(_info!,
                        style: const TextStyle(
                            color: Sanctuary.success, fontSize: 13)),
                  ],
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: _busy ? null : _import,
                    child: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Import'),
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
