import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../data/db/app_db.dart';
import '../../../data/sync/providers.dart';
import '../../../data/sync/sync_service.dart';

class SongsListScreen extends ConsumerWidget {
  const SongsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songs = ref.watch(songsStreamProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 20),
          onPressed: () => context.go('/'),
        ),
        title: const Text('Songs'),
      ),
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
          return RefreshIndicator(
            color: Sanctuary.auroraCyan,
            onRefresh: () => ref.read(syncServiceProvider).syncAll(),
            child: list.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 120),
                      Center(
                        child: Text(
                          'No songs yet.\nPull to sync.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Sanctuary.muted),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _SongRow(song: list[i]),
                  ),
          );
        },
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
        onTap: () => context.go('/songs/${song.id}'),
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
