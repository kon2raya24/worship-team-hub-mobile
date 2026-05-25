import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../../core/supabase_client.dart';
import '../../../data/db/app_db.dart';
import '../../../data/sync/providers.dart';
import '../../../data/sync/sync_service.dart';
import '../../auth/auth_provider.dart';

/// Practice notes for a single song. Drop into the song detail screen.
/// Triggers a syncSongNotes() on mount + after every post/delete.
class SongNotesSection extends ConsumerStatefulWidget {
  const SongNotesSection({super.key, required this.songId});
  final String songId;

  @override
  ConsumerState<SongNotesSection> createState() => _SongNotesSectionState();
}

class _SongNotesSectionState extends ConsumerState<SongNotesSection> {
  final _input = TextEditingController();
  bool _posting = false;

  @override
  void initState() {
    super.initState();
    // ignore: discarded_futures
    ref.read(syncServiceProvider).syncSongNotes(widget.songId);
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final body = _input.text.trim();
    if (body.isEmpty || _posting) return;
    setState(() => _posting = true);
    final ok = await ref
        .read(syncServiceProvider)
        .postSongNote(widget.songId, body);
    if (!mounted) return;
    setState(() => _posting = false);
    if (ok) {
      _input.clear();
      FocusScope.of(context).unfocus();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not post — check your connection.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(songNotesStreamProvider(widget.songId));
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.sticky_note_2_outlined,
                  size: 16, color: Sanctuary.auroraAmber),
              const SizedBox(width: 6),
              Text('PRACTICE NOTES',
                  style: Sanctuary.mono(
                      fontSize: 10, color: Sanctuary.auroraAmber)),
              const Spacer(),
              notes.maybeWhen(
                data: (n) => Text(
                  '${n.length}',
                  style: const TextStyle(
                      color: Sanctuary.muted, fontSize: 11),
                ),
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          notes.when(
            loading: () => const SizedBox(
              height: 32,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (e, _) => Text('Notes failed: $e',
                style: const TextStyle(color: Sanctuary.muted, fontSize: 12)),
            data: (list) => list.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'No notes yet. Drop the first practice tip below.',
                      style: TextStyle(color: Sanctuary.muted, fontSize: 13),
                    ),
                  )
                : Column(
                    children: list.map((n) => _NoteRow(note: n)).toList(),
                  ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Add a note for the team…',
                    isDense: true,
                  ),
                ),
              ),
              IconButton(
                icon: _posting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Sanctuary.auroraAmber),
                      )
                    : const Icon(Icons.send,
                        size: 18, color: Sanctuary.auroraAmber),
                onPressed: _posting ? null : _submit,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NoteRow extends ConsumerWidget {
  const _NoteRow({required this.note});
  final SongNoteRow note;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final author = (note.authorName ?? '').isEmpty
        ? 'Anonymous'
        : note.authorName!;
    final isAuthor = supabase.auth.currentUser?.id == note.authorId;
    final isLeader = ref.watch(isLeaderProvider);
    final canDelete = isAuthor || isLeader;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      author,
                      style: Sanctuary.display(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      DateFormat.MMMd().add_jm().format(note.createdAt),
                      style: const TextStyle(
                          color: Sanctuary.muted, fontSize: 10),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  note.body,
                  style: const TextStyle(
                    color: Sanctuary.foreground,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          if (canDelete)
            IconButton(
              icon: const Icon(Icons.close, size: 14, color: Sanctuary.muted),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              tooltip: 'Delete note',
              onPressed: () async {
                await ref
                    .read(syncServiceProvider)
                    .deleteSongNote(note.songId, note.id);
              },
            ),
        ],
      ),
    );
  }
}
