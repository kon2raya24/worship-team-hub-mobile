import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../data/sync/providers.dart';
import '../../../data/sync/sync_service.dart';
import '../chordpro/chord_line_parse.dart';

class SongComposeScreen extends ConsumerStatefulWidget {
  /// Pass [songId] to edit an existing song; null for create.
  const SongComposeScreen({super.key, this.songId});
  final String? songId;

  @override
  ConsumerState<SongComposeScreen> createState() => _SongComposeScreenState();
}

class _SongComposeScreenState extends ConsumerState<SongComposeScreen> {
  final _title = TextEditingController();
  final _artist = TextEditingController();
  final _key = TextEditingController();
  final _bpm = TextEditingController();
  final _tags = TextEditingController();
  final _chordpro = TextEditingController();
  final _refUrl = TextEditingController();
  bool _busy = false;
  bool _loaded = false;
  String? _error;

  bool get _isEdit => widget.songId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _hydrate();
    } else {
      _loaded = true;
    }
  }

  Future<void> _hydrate() async {
    final s = await ref.read(songByIdProvider(widget.songId!).future);
    if (!mounted) return;
    if (s == null) {
      setState(() {
        _loaded = true;
        _error = 'Song not in local cache. Sync first.';
      });
      return;
    }
    setState(() {
      _title.text = s.title;
      _artist.text = s.artist ?? '';
      _key.text = s.originalKey ?? '';
      _bpm.text = s.bpm?.toString() ?? '';
      _tags.text = s.tagsCsv;
      _chordpro.text = s.chordproBody;
      _refUrl.text = s.referenceUrl ?? '';
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _artist.dispose();
    _key.dispose();
    _bpm.dispose();
    _tags.dispose();
    _chordpro.dispose();
    _refUrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Title is required.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final svc = ref.read(syncServiceProvider);
    final args = {
      'title': title,
      'artist': _artist.text.trim(),
      'originalKey': _key.text.trim(),
      'bpm': int.tryParse(_bpm.text.trim()),
      'tags': _tags.text
          .split(RegExp(r'[,\s]+'))
          .where((t) => t.isNotEmpty)
          .toList(),
      'chordpro': _chordpro.text,
      'refUrl': _refUrl.text.trim(),
    };
    bool ok;
    String? newId;
    if (_isEdit) {
      ok = await svc.updateSong(
        id: widget.songId!,
        title: args['title'] as String,
        artist: args['artist'] as String?,
        originalKey: args['originalKey'] as String?,
        bpm: args['bpm'] as int?,
        tags: args['tags'] as List<String>,
        chordproBody: args['chordpro'] as String,
        referenceUrl: args['refUrl'] as String?,
      );
    } else {
      newId = await svc.createSong(
        title: args['title'] as String,
        artist: args['artist'] as String?,
        originalKey: args['originalKey'] as String?,
        bpm: args['bpm'] as int?,
        tags: args['tags'] as List<String>,
        chordproBody: args['chordpro'] as String,
        referenceUrl: args['refUrl'] as String?,
      );
      ok = newId != null;
    }
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEdit ? 'Song updated.' : 'Song added.')),
      );
      if (_isEdit) {
        context.pop();
      } else {
        // Replace this stack with the song detail so back returns to list.
        context.go('/songs/${newId!}');
      }
    } else {
      setState(() {
        _busy = false;
        _error = 'Save failed. Check connection or leader role.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
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
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/songs'),
        ),
        title: Text(_isEdit ? 'Edit song' : 'New song'),
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
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(hintText: 'Title'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _artist,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(hintText: 'Artist'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _key,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                              hintText: 'Original key (G)'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _bpm,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(hintText: 'BPM (90)'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _tags,
                    decoration: const InputDecoration(
                      hintText: 'Tags (comma-separated)',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _refUrl,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      hintText: 'Reference URL (YouTube / Spotify)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text('CHORDPRO BODY',
                          style: Sanctuary.mono(fontSize: 10)),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () {
                          final input = _chordpro.text;
                          if (input.trim().isEmpty) return;
                          final converted = convertChordOverLyrics(input);
                          if (converted == input) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Body already looks like ChordPro — nothing changed.',
                                ),
                              ),
                            );
                            return;
                          }
                          setState(() => _chordpro.text = converted);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Converted chord lines to inline ChordPro.'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.auto_fix_high, size: 14),
                        label: const Text('Convert chord lines'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _chordpro,
                    minLines: 10,
                    maxLines: 24,
                    style: Sanctuary.mono(
                      fontSize: 13,
                      color: Sanctuary.foreground,
                      letterSpacing: 0,
                    ),
                    decoration: const InputDecoration(
                      hintText:
                          '{title: ...}\n{key: G}\n[G]Lyric [Am]words [C]here',
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
                        : Text(_isEdit ? 'Save changes' : 'Add song'),
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
