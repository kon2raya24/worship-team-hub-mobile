import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../data/db/app_db.dart';
import '../../../data/sync/providers.dart';
import '../../../data/sync/sync_service.dart';

class SetlistAddSongScreen extends ConsumerStatefulWidget {
  const SetlistAddSongScreen({super.key, required this.setlistId});
  final String setlistId;

  @override
  ConsumerState<SetlistAddSongScreen> createState() =>
      _SetlistAddSongScreenState();
}

class _SetlistAddSongScreenState extends ConsumerState<SetlistAddSongScreen> {
  final _search = TextEditingController();
  String _query = '';
  SongRow? _selected;
  final _key = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _search.dispose();
    _key.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final song = _selected;
    if (song == null) return;
    setState(() => _busy = true);
    // Fetch current positions and append at the end.
    final existing = await ref
        .read(appDbProvider)
        .getSetlistSongs(widget.setlistId);
    final nextPos = existing.isEmpty
        ? 1
        : existing.map((s) => s.position).reduce((a, b) => a > b ? a : b) + 1;
    final key =
        _key.text.trim().isEmpty ? song.originalKey : _key.text.trim();
    final ok = await ref.read(syncServiceProvider).addSongToSetlist(
          widget.setlistId,
          song.id,
          nextPos,
          playedInKey: key,
        );
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${song.title} added.')),
      );
      context.pop();
    } else {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not add — check connection.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final songs = ref.watch(songsStreamProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 20),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go('/setlists/${widget.setlistId}'),
        ),
        title: const Text('Add song'),
      ),
      body: SafeArea(
        child: songs.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text('Failed to load songs.\n$e',
                style: TextStyle(color: cs.onSurfaceVariant)),
          ),
          data: (list) {
            final filtered = _query.isEmpty
                ? list
                : list.where((s) {
                    final q = _query.toLowerCase();
                    return s.title.toLowerCase().contains(q) ||
                        (s.artist ?? '').toLowerCase().contains(q);
                  }).toList();
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: TextField(
                    controller: _search,
                    onChanged: (v) => setState(() => _query = v),
                    decoration: const InputDecoration(
                      hintText: 'Search title or artist…',
                      prefixIcon: Icon(Icons.search, size: 18),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final s = filtered[i];
                      final selected = _selected?.id == s.id;
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius:
                              BorderRadius.circular(Sanctuary.radiusMd),
                          onTap: () {
                            setState(() {
                              _selected = s;
                              _key.text = s.originalKey ?? '';
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: selected
                                  ? cs.secondary.withValues(alpha: 0.1)
                                  : (isDark
                                      ? Sanctuary.glass1
                                      : Sanctuary.lightGlass1),
                              border: Border.all(
                                color: selected
                                    ? cs.secondary.withValues(alpha: 0.5)
                                    : cs.outlineVariant,
                              ),
                              borderRadius: BorderRadius.circular(
                                  Sanctuary.radiusMd),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(s.title,
                                          style: Sanctuary.display(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600)),
                                      if ((s.artist ?? '').isNotEmpty)
                                        Text(s.artist!,
                                            style: TextStyle(
                                                color: cs.onSurfaceVariant,
                                                fontSize: 12)),
                                    ],
                                  ),
                                ),
                                if ((s.originalKey ?? '').isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: cs.secondary
                                          .withValues(alpha: 0.1),
                                      border: Border.all(
                                          color: cs.secondary
                                              .withValues(alpha: 0.3)),
                                      borderRadius:
                                          BorderRadius.circular(
                                              Sanctuary.radiusSm),
                                    ),
                                    child: Text(
                                      s.originalKey!,
                                      style: Sanctuary.mono(
                                          fontSize: 11,
                                          color: cs.secondary,
                                          letterSpacing: 0),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (_selected != null) ...[
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: GlassCard(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _key,
                              textCapitalization:
                                  TextCapitalization.characters,
                              decoration: const InputDecoration(
                                hintText: 'Play in key (e.g. G)',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          FilledButton(
                            onPressed: _busy ? null : _add,
                            child: _busy
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : Text('Add ${_selected!.title}',
                                    overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
