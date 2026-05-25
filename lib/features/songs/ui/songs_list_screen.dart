import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../data/db/app_db.dart';
import '../../../data/sync/providers.dart';
import '../../../data/sync/sync_service.dart';
import '../../auth/auth_provider.dart';

class SongsListScreen extends ConsumerStatefulWidget {
  const SongsListScreen({super.key});

  @override
  ConsumerState<SongsListScreen> createState() => _SongsListScreenState();
}

class _SongsListScreenState extends ConsumerState<SongsListScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(SongRow s, String q) {
    if (q.isEmpty) return true;
    final lower = q.toLowerCase();
    return s.title.toLowerCase().contains(lower) ||
        (s.artist ?? '').toLowerCase().contains(lower) ||
        (s.tagsCsv).toLowerCase().contains(lower);
  }

  @override
  Widget build(BuildContext context) {
    final songs = ref.watch(songsStreamProvider);
    final isLeader = ref.watch(isLeaderProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 20),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: const Text('Songs'),
      ),
      floatingActionButton: isLeader
          ? FloatingActionButton.extended(
              backgroundColor: Sanctuary.auroraViolet,
              foregroundColor: Colors.white,
              onPressed: () => context.push('/songs/new'),
              icon: const Icon(Icons.add),
              label: const Text('New'),
            )
          : null,
      body: songs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Failed to load songs.\n$e',
              style: const TextStyle(color: Sanctuary.muted),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (list) {
          final filtered = list.where((s) => _matches(s, _query)).toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: _SearchBar(
                  controller: _search,
                  onChanged: (v) => setState(() => _query = v),
                  total: list.length,
                  shown: filtered.length,
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  color: Sanctuary.auroraCyan,
                  onRefresh: () => ref.read(syncServiceProvider).syncAll(),
                  child: filtered.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            const SizedBox(height: 120),
                            Center(
                              child: Text(
                                list.isEmpty
                                    ? 'No songs yet.\nPull to sync.'
                                    : 'No matches for "$_query"',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Sanctuary.muted),
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) => _SongRow(song: filtered[i]),
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.total,
    required this.shown,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final int total;
  final int shown;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: Sanctuary.glass1,
        border: Border.all(color: Sanctuary.hairline),
        borderRadius: BorderRadius.circular(Sanctuary.radiusLg),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 18, color: Sanctuary.muted),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              style: const TextStyle(
                color: Sanctuary.foreground,
                fontSize: 14,
              ),
              decoration: const InputDecoration(
                hintText: 'Search title, artist, tag…',
                hintStyle: TextStyle(color: Sanctuary.muted, fontSize: 14),
                border: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear, size: 18, color: Sanctuary.muted),
              tooltip: 'Clear',
              onPressed: () {
                controller.clear();
                onChanged('');
              },
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                '$total',
                style: const TextStyle(color: Sanctuary.muted, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

class _SongRow extends StatelessWidget {
  const _SongRow({required this.song});

  final SongRow song;

  @override
  Widget build(BuildContext context) {
    final artist = song.artist;
    final key = song.originalKey;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(Sanctuary.radiusLg),
        onTap: () => context.push('/songs/${song.id}'),
        child: GlassCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      style: Sanctuary.display(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (artist != null && artist.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        artist,
                        style: const TextStyle(
                          color: Sanctuary.muted,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (key != null && key.isNotEmpty) ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Sanctuary.auroraCyan.withValues(alpha: 0.1),
                    border: Border.all(
                      color: Sanctuary.auroraCyan.withValues(alpha: 0.3),
                    ),
                    borderRadius: BorderRadius.circular(Sanctuary.radiusSm),
                  ),
                  child: Text(
                    key,
                    style: Sanctuary.mono(
                      fontSize: 12,
                      color: Sanctuary.auroraCyan,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
