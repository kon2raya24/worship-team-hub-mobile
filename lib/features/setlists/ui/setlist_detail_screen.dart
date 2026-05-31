import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/env.dart';
import '../../../core/theme.dart';
import '../../../data/db/app_db.dart';
import '../../../data/sync/providers.dart';
import '../../../data/sync/sync_service.dart';
import '../../auth/auth_provider.dart';

class SetlistDetailScreen extends ConsumerStatefulWidget {
  const SetlistDetailScreen({super.key, required this.setlistId});

  final String setlistId;

  @override
  ConsumerState<SetlistDetailScreen> createState() =>
      _SetlistDetailScreenState();
}

class _SetlistDetailScreenState extends ConsumerState<SetlistDetailScreen> {
  // Local working copy of the song order so drag-reorder shows instantly;
  // re-seeded from synced data whenever the song membership changes.
  List<SetlistSongWithSong>? _ordered;

  String get setlistId => widget.setlistId;

  Future<void> _confirmDeleteSetlist() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Sanctuary.ink2,
        title: const Text('Delete setlist?'),
        content: const Text(
          'The Sunday plan and song order will be removed for the whole team.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Sanctuary.destructive,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final deleted =
        await ref.read(syncServiceProvider).deleteSetlist(setlistId);
    if (!mounted) return;
    if (deleted) {
      context.go('/setlists');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delete failed.')),
      );
    }
  }

  Future<void> _share() async {
    final token = await ref
        .read(syncServiceProvider)
        .createShareLink(resourceType: 'setlist', resourceId: setlistId);
    if (!mounted) return;
    if (token != null) {
      await Share.share('${Env.webBaseUrl}/share/$token');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not create share link.')),
      );
    }
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    // ReorderableListView's onReorderItem already adjusts newIndex for the
    // item removed at oldIndex, so we remove + insert directly.
    final list = List.of(_ordered ?? const <SetlistSongWithSong>[]);
    final moved = list.removeAt(oldIndex);
    list.insert(newIndex, moved);
    setState(() => _ordered = list);
    final ok = await ref.read(syncServiceProvider).reorderSetlistSongs(
          setlistId,
          list.map((e) => e.join.songId).toList(),
        );
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save the new order.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final songsAsync = ref.watch(setlistSongsProvider(setlistId));
    final setlist = ref.watch(setlistByIdProvider(setlistId)).valueOrNull;
    final isLeader = ref.watch(isLeaderProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 20),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/setlists'),
        ),
        title: const Text('Setlist'),
        actions: [
          if (isLeader)
            IconButton(
              icon: const Icon(Icons.ios_share, size: 20),
              tooltip: 'Share link',
              onPressed: _share,
            ),
          if (isLeader)
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              tooltip: 'Edit setlist',
              onPressed: () => context.push('/setlists/$setlistId/edit'),
            ),
          if (isLeader)
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  size: 20, color: Sanctuary.destructive),
              tooltip: 'Delete setlist',
              onPressed: _confirmDeleteSetlist,
            ),
        ],
      ),
      floatingActionButton: isLeader
          ? FloatingActionButton.extended(
              backgroundColor: Sanctuary.auroraCyan,
              foregroundColor: Sanctuary.ink0,
              onPressed: () => context.push('/setlists/$setlistId/add-song'),
              icon: const Icon(Icons.library_music_outlined),
              label: const Text('Add song'),
            )
          : null,
      body: songsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            'Failed to load setlist.\n$e',
            style: const TextStyle(color: Sanctuary.muted),
          ),
        ),
        data: (items) {
          // Re-seed the local order when membership changes (song added or
          // removed) or on first load. Drag-reorders mutate the copy in place.
          final cur = _ordered;
          final sameMembership = cur != null &&
              cur.length == items.length &&
              cur.every(
                (o) => items.any((i) => i.join.songId == o.join.songId),
              );
          if (!sameMembership) {
            _ordered = List.of(items);
          }
          final list = _ordered!;

          final header =
              setlist != null ? _SetlistHeader(setlist: setlist) : null;

          if (list.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (header != null) header,
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      'No songs in this setlist.',
                      style: TextStyle(color: Sanctuary.muted),
                    ),
                  ),
                ),
              ],
            );
          }

          if (isLeader) {
            // Long-press a row to drag it into a new position.
            return ReorderableListView.builder(
              padding: const EdgeInsets.all(16),
              header: header == null
                  ? null
                  : Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: header,
                    ),
              itemCount: list.length,
              onReorderItem: _onReorder,
              itemBuilder: (context, i) => Padding(
                key: ValueKey(list[i].join.songId),
                padding: const EdgeInsets.only(bottom: 10),
                child: _SetlistSongRow(
                  position: i + 1,
                  item: list[i],
                  isLeader: isLeader,
                  setlistId: setlistId,
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (header != null) header,
              const SizedBox(height: 16),
              ...list.asMap().entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _SetlistSongRow(
                        position: entry.key + 1,
                        item: entry.value,
                        isLeader: isLeader,
                        setlistId: setlistId,
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

class _SetlistSongRow extends ConsumerWidget {
  const _SetlistSongRow({
    required this.position,
    required this.item,
    required this.isLeader,
    required this.setlistId,
  });

  final int position;
  final SetlistSongWithSong item;
  final bool isLeader;
  final String setlistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              if (isLeader)
                IconButton(
                  icon: const Icon(Icons.close,
                      size: 18, color: Sanctuary.muted),
                  tooltip: 'Remove from setlist',
                  onPressed: () async {
                    final ok = await ref
                        .read(syncServiceProvider)
                        .removeSongFromSetlist(setlistId, song.id);
                    if (!context.mounted) return;
                    if (!ok) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Could not remove song.')),
                      );
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
