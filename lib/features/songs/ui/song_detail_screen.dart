import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/supabase_client.dart';
import '../../../core/theme.dart';

final songProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, id) async {
  final row = await supabase
      .from('songs')
      .select('id, title, artist, original_key, bpm, chordpro_body')
      .eq('id', id)
      .maybeSingle();
  return row;
});

/// Phase 1 placeholder. Real chord viewer (parser + transposer + formatter)
/// lands in the songs/chordpro/ module next sprint.
class SongDetailScreen extends ConsumerWidget {
  const SongDetailScreen({super.key, required this.songId});

  final String songId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final song = ref.watch(songProvider(songId));
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 20),
          onPressed: () => context.go('/songs'),
        ),
        title: const Text('Chord chart'),
      ),
      body: song.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Failed to load song.\n$e',
              style: const TextStyle(color: Sanctuary.muted)),
        ),
        data: (s) {
          if (s == null) {
            return const Center(child: Text('Song not found'));
          }
          final body = (s['chordpro_body'] as String? ?? '').trim();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(s['title'] as String? ?? '',
                  style: Sanctuary.display(fontSize: 26)),
              if ((s['artist'] as String?)?.isNotEmpty == true) ...[
                const SizedBox(height: 4),
                Text(s['artist'] as String,
                    style: const TextStyle(
                        color: Sanctuary.muted, fontSize: 14)),
              ],
              const SizedBox(height: 16),
              GlassCard(
                child: body.isEmpty
                    ? const Text('No chord chart yet.',
                        style: TextStyle(color: Sanctuary.muted))
                    : SelectableText(
                        body,
                        style: const TextStyle(
                            fontFamily: 'monospace',
                            color: Sanctuary.foreground,
                            fontSize: 13,
                            height: 1.5),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
