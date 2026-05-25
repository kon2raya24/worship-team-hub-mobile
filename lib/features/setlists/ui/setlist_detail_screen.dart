import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../../data/db/app_db.dart';
import '../../../data/sync/providers.dart';

class SetlistDetailScreen extends ConsumerWidget {
  const SetlistDetailScreen({super.key, required this.setlistId});

  final String setlistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songs = ref.watch(setlistSongsProvider(setlistId));
    final setlists = ref.watch(upcomingSetlistsStreamProvider);
    final setlist = setlists.maybeWhen(
      data: (list) => list.where((s) => s.id == setlistId).firstOrNull,
      orElse: () => null,
    );
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 20),
          onPressed: () => context.canPop() ? context.pop() : context.go('/setlists'),
        ),
        title: const Text('Setlist'),
      ),
      body: songs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            'Failed to load setlist.\n$e',
            style: const TextStyle(color: Sanctuary.muted),
          ),
        ),
        data: (items) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (setlist != null) _SetlistHeader(setlist: setlist),
              const SizedBox(height: 16),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      'No songs in this setlist.',
                      style: TextStyle(color: Sanctuary.muted),
                    ),
                  ),
                )
              else
                ...items.asMap().entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _SetlistSongRow(
                          position: entry.key + 1,
                          item: entry.value,
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

class _SetlistHeader extends StatelessWidget {
  const _SetlistHeader({required this.setlist});
  final SetlistRow setlist;

  @override
  Widget build(BuildContext context) {
    final date = setlist.serviceDate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              color: Sanctuary.auroraViolet,
              size: 14,
            ),
            const SizedBox(width: 6),
            Text(
              DateFormat('EEE').format(date).toUpperCase(),
              style: Sanctuary.mono(
                fontSize: 11,
                color: Sanctuary.auroraViolet,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          DateFormat('EEEE, MMMM d').format(date),
          style: Sanctuary.display(fontSize: 24),
        ),
        if ((setlist.theme ?? '').isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            setlist.theme!,
            style: const TextStyle(color: Sanctuary.muted, fontSize: 14),
          ),
        ],
        if ((setlist.notes ?? '').isNotEmpty) ...[
          const SizedBox(height: 12),
          GlassCard(
            padding: const EdgeInsets.all(14),
            child: Text(
              setlist.notes!,
              style: const TextStyle(color: Sanctuary.foreground, fontSize: 13),
            ),
          ),
        ],
      ],
    );
  }
}

class _SetlistSongRow extends StatelessWidget {
  const _SetlistSongRow({required this.position, required this.item});

  final int position;
  final SetlistSongWithSong item;

  @override
  Widget build(BuildContext context) {
    final song = item.song;
    final playedKey = item.join.playedInKey;
    final displayKey =
        (playedKey ?? '').isNotEmpty ? playedKey : song.originalKey;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(Sanctuary.radiusLg),
        onTap: () {
          final query = (playedKey ?? '').isNotEmpty
              ? '?key=${Uri.encodeQueryComponent(playedKey!)}'
              : '';
          context.push('/songs/${song.id}$query');
        },
        child: GlassCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  '$position',
                  style: Sanctuary.mono(
                    fontSize: 16,
                    color: Sanctuary.muted,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
              ),
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
                    if ((song.artist ?? '').isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        song.artist!,
                        style: const TextStyle(
                          color: Sanctuary.muted,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if ((displayKey ?? '').isNotEmpty) ...[
                const SizedBox(width: 8),
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
                    displayKey!,
                    style: Sanctuary.mono(
                      fontSize: 12,
                      color: Sanctuary.auroraCyan,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
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
