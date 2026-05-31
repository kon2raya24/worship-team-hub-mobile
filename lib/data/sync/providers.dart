import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_db.dart';
import 'sync_service.dart';

/// Drift stream of the entire local song library, sorted by title.
final songsStreamProvider = StreamProvider<List<SongRow>>((ref) {
  final db = ref.watch(appDbProvider);
  return db.watchAllSongs();
});

/// Single-song lookup from local DB. A *stream* (not a one-shot future) so the
/// detail view live-updates after an edit syncs — matching [songsStreamProvider].
final songByIdProvider = StreamProvider.family<SongRow?, String>((ref, id) {
  final db = ref.watch(appDbProvider);
  return db.watchSong(id);
});

/// Upcoming setlists (today onward).
final upcomingSetlistsStreamProvider = StreamProvider<List<SetlistRow>>((ref) {
  final db = ref.watch(appDbProvider);
  return db.watchUpcomingSetlists();
});

/// Past setlists (before today), newest first — the browsable history.
final pastSetlistsStreamProvider = StreamProvider<List<SetlistRow>>((ref) {
  final db = ref.watch(appDbProvider);
  return db.watchPastSetlists();
});

/// Single-setlist lookup (past or upcoming) so the detail screen can open any
/// setlist, not just upcoming ones.
final setlistByIdProvider =
    StreamProvider.family<SetlistRow?, String>((ref, id) {
  final db = ref.watch(appDbProvider);
  return db.watchSetlist(id);
});

/// Songs in a given setlist, joined to song metadata, ordered by position.
final setlistSongsProvider =
    FutureProvider.family<List<SetlistSongWithSong>, String>((ref, setlistId) async {
  final db = ref.watch(appDbProvider);
  final joins = await db.getSetlistSongs(setlistId);
  final results = <SetlistSongWithSong>[];
  for (final j in joins) {
    final song = await db.getSong(j.songId);
    if (song != null) {
      results.add(SetlistSongWithSong(join: j, song: song));
    }
  }
  return results;
});

class SetlistSongWithSong {
  SetlistSongWithSong({required this.join, required this.song});
  final SetlistSongRow join;
  final SongRow song;
}

/// Fires once on first read after sign-in. Subsequent reads return the cached
/// future. Use `ref.invalidate(startupSyncProvider)` to force a refresh.
final startupSyncProvider = FutureProvider<SyncResult>((ref) async {
  final svc = ref.read(syncServiceProvider);
  return svc.syncAll();
});

/// Upcoming schedule assignments, joined to member display name.
final upcomingScheduleStreamProvider =
    StreamProvider<List<UpcomingAssignment>>((ref) {
  final db = ref.watch(appDbProvider);
  return db.watchUpcomingAssignments();
});

final devotionsStreamProvider = StreamProvider<List<DevotionRow>>((ref) {
  return ref.watch(appDbProvider).watchDevotions();
});

final devotionByIdProvider =
    StreamProvider.family<DevotionRow?, String>((ref, id) {
  return ref.watch(appDbProvider).watchDevotion(id);
});

final prayerRequestsStreamProvider =
    StreamProvider<List<PrayerRequestRow>>((ref) {
  return ref.watch(appDbProvider).watchPrayerRequests();
});

final announcementsStreamProvider =
    StreamProvider<List<AnnouncementRow>>((ref) {
  return ref.watch(appDbProvider).watchAnnouncements();
});

/// All synced team members — used by the schedule editor's member picker
/// and the /team page.
final allProfilesProvider = FutureProvider<List<ProfileRow>>((ref) {
  return ref.watch(appDbProvider).allProfiles();
});

/// Notes for a single song. Watches Drift; the screen triggers a
/// syncSongNotes() on open to make sure the cache is fresh.
final songNotesStreamProvider =
    StreamProvider.family<List<SongNoteRow>, String>((ref, songId) {
  return ref.watch(appDbProvider).watchSongNotes(songId);
});
