import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase_client.dart';
import '../db/app_db.dart';

final appDbProvider = Provider<AppDb>((ref) {
  final db = AppDb();
  ref.onDispose(db.close);
  return db;
});

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(ref.read(appDbProvider));
});

/// Pulls songs + upcoming setlists from Supabase and writes them into Drift.
/// Last-write-wins; the local cache is treated as a read-through mirror.
class SyncService {
  SyncService(this._db);

  final AppDb _db;
  bool _syncing = false;
  DateTime? _lastSyncedAt;

  DateTime? get lastSyncedAt => _lastSyncedAt;
  bool get isSyncing => _syncing;

  Future<SyncResult> syncAll() async {
    if (_syncing) return SyncResult.skipped;
    _syncing = true;
    try {
      await Future.wait([
        _syncSongs(),
        _syncSetlistsAndJoins(),
        _syncProfilesAndSchedule(),
        _syncDevotions(),
        _syncPrayerRequests(),
        _syncAnnouncements(),
      ]);
      _lastSyncedAt = DateTime.now();
      return SyncResult.ok;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('Sync failed: $e\n$st');
      }
      return SyncResult.failed;
    } finally {
      _syncing = false;
    }
  }

  Future<void> _syncSongs() async {
    final rows = await supabase
        .from('songs')
        .select(
          'id, title, artist, original_key, bpm, tags, chordpro_body, reference_url, updated_at',
        );
    final companions = (rows as List).map((r) {
      final m = r as Map<String, dynamic>;
      final tags = (m['tags'] as List?)?.cast<String>() ?? const <String>[];
      return SongsCompanion.insert(
        id: m['id'] as String,
        title: m['title'] as String,
        artist: Value(m['artist'] as String?),
        originalKey: Value(m['original_key'] as String?),
        bpm: Value(m['bpm'] as int?),
        tagsCsv: Value(tags.join(',')),
        chordproBody: Value((m['chordpro_body'] as String?) ?? ''),
        referenceUrl: Value(m['reference_url'] as String?),
        updatedAt: DateTime.parse(m['updated_at'] as String),
      );
    }).toList();
    await _db.replaceSongs(companions);
  }

  Future<void> _syncSetlistsAndJoins() async {
    final today = DateTime.now();
    final cutoff = DateTime(today.year, today.month, today.day)
        .toIso8601String()
        .substring(0, 10);
    final rows = await supabase
        .from('setlists')
        .select(
          'id, service_date, theme, notes, setlist_songs(setlist_id, song_id, played_in_key, position)',
        )
        .gte('service_date', cutoff)
        .order('service_date');

    final setlistCompanions = <SetlistsCompanion>[];
    final perSetlistSongs = <String, List<SetlistSongsCompanion>>{};

    for (final r in rows as List) {
      final m = r as Map<String, dynamic>;
      final id = m['id'] as String;
      setlistCompanions.add(
        SetlistsCompanion.insert(
          id: id,
          serviceDate: DateTime.parse(m['service_date'] as String),
          theme: Value(m['theme'] as String?),
          notes: Value(m['notes'] as String?),
        ),
      );
      final joins = (m['setlist_songs'] as List?) ?? const [];
      perSetlistSongs[id] = joins.map((j) {
        final jm = j as Map<String, dynamic>;
        return SetlistSongsCompanion.insert(
          setlistId: jm['setlist_id'] as String,
          songId: jm['song_id'] as String,
          playedInKey: Value(jm['played_in_key'] as String?),
          position: jm['position'] as int,
        );
      }).toList();
    }

    await _db.replaceSetlists(setlistCompanions);
    for (final entry in perSetlistSongs.entries) {
      await _db.replaceSetlistSongs(entry.key, entry.value);
    }
  }

  Future<void> _syncProfilesAndSchedule() async {
    final today = DateTime.now();
    final cutoff = DateTime(today.year, today.month, today.day)
        .toIso8601String()
        .substring(0, 10);

    final results = await Future.wait([
      supabase.from('profiles').select('id, display_name, role'),
      supabase
          .from('schedule_assignments')
          .select('id, service_date, user_id, role')
          .gte('service_date', cutoff)
          .order('service_date'),
    ]);

    final profileRows = (results[0] as List).map((r) {
      final m = r as Map<String, dynamic>;
      return ProfilesCompanion.insert(
        id: m['id'] as String,
        displayName: m['display_name'] as String,
        role: Value((m['role'] as String?) ?? 'member'),
      );
    }).toList();
    await _db.replaceProfiles(profileRows);

    final assignmentRows = (results[1] as List).map((r) {
      final m = r as Map<String, dynamic>;
      return ScheduleAssignmentsCompanion.insert(
        id: m['id'] as String,
        serviceDate: DateTime.parse(m['service_date'] as String),
        userId: m['user_id'] as String,
        role: m['role'] as String,
      );
    }).toList();
    await _db.replaceUpcomingAssignments(assignmentRows);
  }

  Future<void> _syncDevotions() async {
    final rows = await supabase
        .from('devotions')
        .select('id, title, body, scripture_ref, published_at')
        .order('published_at', ascending: false)
        .limit(50);
    final companions = (rows as List).map((r) {
      final m = r as Map<String, dynamic>;
      return DevotionsCompanion.insert(
        id: m['id'] as String,
        title: m['title'] as String,
        body: m['body'] as String,
        scriptureRef: Value(m['scripture_ref'] as String?),
        publishedAt: DateTime.parse(m['published_at'] as String),
      );
    }).toList();
    await _db.replaceDevotions(companions);
  }

  Future<void> _syncPrayerRequests() async {
    final rows = await supabase
        .from('prayer_requests')
        .select(
          'id, author_id, body, is_answered, created_at, profiles(display_name)',
        )
        .order('created_at', ascending: false)
        .limit(100);
    final companions = (rows as List).map((r) {
      final m = r as Map<String, dynamic>;
      final author = m['profiles'] as Map<String, dynamic>?;
      return PrayerRequestsCompanion.insert(
        id: m['id'] as String,
        authorId: Value(m['author_id'] as String?),
        authorName: Value(author?['display_name'] as String?),
        body: m['body'] as String,
        isAnswered: Value((m['is_answered'] as bool?) ?? false),
        createdAt: DateTime.parse(m['created_at'] as String),
      );
    }).toList();
    await _db.replacePrayerRequests(companions);
  }

  Future<void> _syncAnnouncements() async {
    final rows = await supabase
        .from('announcements')
        .select('id, title, body, pinned, created_at')
        .order('created_at', ascending: false)
        .limit(50);
    final companions = (rows as List).map((r) {
      final m = r as Map<String, dynamic>;
      return AnnouncementsCompanion.insert(
        id: m['id'] as String,
        title: m['title'] as String,
        body: m['body'] as String,
        pinned: Value((m['pinned'] as bool?) ?? false),
        createdAt: DateTime.parse(m['created_at'] as String),
      );
    }).toList();
    await _db.replaceAnnouncements(companions);
  }

  /// Toggle "answered" on a prayer request. Author or leader per web RLS.
  Future<bool> setPrayerAnswered(String id, bool answered) async {
    try {
      await supabase
          .from('prayer_requests')
          .update({'is_answered': answered})
          .eq('id', id);
      await _syncPrayerRequests();
      return true;
    } catch (e, st) {
      if (kDebugMode) debugPrint('Set prayer answered failed: $e\n$st');
      return false;
    }
  }

  /// Delete a prayer request. Author or leader per web RLS.
  Future<bool> deletePrayerRequest(String id) async {
    try {
      await supabase.from('prayer_requests').delete().eq('id', id);
      await _syncPrayerRequests();
      return true;
    } catch (e, st) {
      if (kDebugMode) debugPrint('Delete prayer failed: $e\n$st');
      return false;
    }
  }

  Future<bool> postPrayerRequest(String body) async {
    final user = supabase.auth.currentUser;
    if (user == null) return false;
    try {
      await supabase
          .from('prayer_requests')
          .insert({'author_id': user.id, 'body': body});
      await _syncPrayerRequests();
      return true;
    } catch (e, st) {
      if (kDebugMode) debugPrint('Post prayer failed: $e\n$st');
      return false;
    }
  }

  /// Leader-only — insert a new announcement and re-sync the feed.
  /// Returns the new row id on success, null on failure.
  Future<String?> postAnnouncement({
    required String title,
    required String body,
    bool pinned = false,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) return null;
    try {
      final inserted = await supabase
          .from('announcements')
          .insert({
            'author_id': user.id,
            'title': title,
            'body': body,
            'pinned': pinned,
          })
          .select('id')
          .single();
      await _syncAnnouncements();
      return inserted['id'] as String?;
    } catch (e, st) {
      if (kDebugMode) debugPrint('Post announcement failed: $e\n$st');
      return null;
    }
  }

  /// Toggle pin on an announcement. Leader-only via RLS.
  Future<bool> togglePinAnnouncement(String id, bool pinned) async {
    try {
      await supabase
          .from('announcements')
          .update({'pinned': pinned})
          .eq('id', id);
      await _syncAnnouncements();
      return true;
    } catch (e, st) {
      if (kDebugMode) debugPrint('Toggle pin failed: $e\n$st');
      return false;
    }
  }

  /// Delete an announcement. Leader-only via RLS.
  Future<bool> deleteAnnouncement(String id) async {
    try {
      await supabase.from('announcements').delete().eq('id', id);
      await _syncAnnouncements();
      return true;
    } catch (e, st) {
      if (kDebugMode) debugPrint('Delete announcement failed: $e\n$st');
      return false;
    }
  }

  // ── Devotions (leader writes) ──────────────────────────────────────
  Future<String?> postDevotion({
    required String title,
    required String body,
    String? scriptureRef,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) return null;
    try {
      final row = await supabase
          .from('devotions')
          .insert({
            'author_id': user.id,
            'title': title,
            'body': body,
            if (scriptureRef != null && scriptureRef.isNotEmpty)
              'scripture_ref': scriptureRef,
          })
          .select('id')
          .single();
      await _syncDevotions();
      return row['id'] as String?;
    } catch (e, st) {
      if (kDebugMode) debugPrint('Post devotion failed: $e\n$st');
      return null;
    }
  }

  Future<bool> deleteDevotion(String id) async {
    try {
      await supabase.from('devotions').delete().eq('id', id);
      await _syncDevotions();
      return true;
    } catch (e, st) {
      if (kDebugMode) debugPrint('Delete devotion failed: $e\n$st');
      return false;
    }
  }

  // ── Songs (leader writes) ──────────────────────────────────────────
  Future<String?> createSong({
    required String title,
    String? artist,
    String? originalKey,
    int? bpm,
    List<String> tags = const [],
    String chordproBody = '',
    String? referenceUrl,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) return null;
    try {
      final row = await supabase
          .from('songs')
          .insert({
            'created_by': user.id,
            'title': title,
            if (artist != null && artist.isNotEmpty) 'artist': artist,
            if (originalKey != null && originalKey.isNotEmpty)
              'original_key': originalKey,
            if (bpm != null) 'bpm': bpm,
            'tags': tags,
            'chordpro_body': chordproBody,
            if (referenceUrl != null && referenceUrl.isNotEmpty)
              'reference_url': referenceUrl,
          })
          .select('id')
          .single();
      await _syncSongs();
      return row['id'] as String?;
    } catch (e, st) {
      if (kDebugMode) debugPrint('Create song failed: $e\n$st');
      return null;
    }
  }

  Future<bool> updateSong({
    required String id,
    required String title,
    String? artist,
    String? originalKey,
    int? bpm,
    List<String> tags = const [],
    String chordproBody = '',
    String? referenceUrl,
  }) async {
    try {
      await supabase.from('songs').update({
        'title': title,
        'artist': artist,
        'original_key': originalKey,
        'bpm': bpm,
        'tags': tags,
        'chordpro_body': chordproBody,
        'reference_url': referenceUrl,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', id);
      await _syncSongs();
      return true;
    } catch (e, st) {
      if (kDebugMode) debugPrint('Update song failed: $e\n$st');
      return false;
    }
  }

  Future<bool> deleteSong(String id) async {
    try {
      await supabase.from('songs').delete().eq('id', id);
      await _syncSongs();
      return true;
    } catch (e, st) {
      if (kDebugMode) debugPrint('Delete song failed: $e\n$st');
      return false;
    }
  }

  // ── Setlists (leader writes) ───────────────────────────────────────
  Future<String?> createSetlist({
    required DateTime serviceDate,
    String? theme,
    String? notes,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) return null;
    try {
      final row = await supabase
          .from('setlists')
          .insert({
            'service_date':
                serviceDate.toIso8601String().substring(0, 10),
            if (theme != null && theme.isNotEmpty) 'theme': theme,
            if (notes != null && notes.isNotEmpty) 'notes': notes,
            'leader_id': user.id,
          })
          .select('id')
          .single();
      await _syncSetlistsAndJoins();
      return row['id'] as String?;
    } catch (e, st) {
      if (kDebugMode) debugPrint('Create setlist failed: $e\n$st');
      return null;
    }
  }

  Future<bool> deleteSetlist(String id) async {
    try {
      await supabase.from('setlists').delete().eq('id', id);
      await _syncSetlistsAndJoins();
      return true;
    } catch (e, st) {
      if (kDebugMode) debugPrint('Delete setlist failed: $e\n$st');
      return false;
    }
  }

  Future<bool> addSongToSetlist(
    String setlistId,
    String songId,
    int position, {
    String? playedInKey,
  }) async {
    try {
      await supabase.from('setlist_songs').insert({
        'setlist_id': setlistId,
        'song_id': songId,
        'position': position,
        if (playedInKey != null && playedInKey.isNotEmpty)
          'played_in_key': playedInKey,
      });
      await _syncSetlistsAndJoins();
      return true;
    } catch (e, st) {
      if (kDebugMode) debugPrint('Add song to setlist failed: $e\n$st');
      return false;
    }
  }

  Future<bool> removeSongFromSetlist(String setlistId, String songId) async {
    try {
      await supabase
          .from('setlist_songs')
          .delete()
          .eq('setlist_id', setlistId)
          .eq('song_id', songId);
      await _syncSetlistsAndJoins();
      return true;
    } catch (e, st) {
      if (kDebugMode) debugPrint('Remove song from setlist failed: $e\n$st');
      return false;
    }
  }

  // ── Schedule (leader writes) ───────────────────────────────────────
  Future<bool> assignToSchedule({
    required DateTime serviceDate,
    required String userId,
    required String role,
  }) async {
    try {
      await supabase.from('schedule_assignments').insert({
        'service_date':
            serviceDate.toIso8601String().substring(0, 10),
        'user_id': userId,
        'role': role,
      });
      await _syncProfilesAndSchedule();
      return true;
    } catch (e, st) {
      if (kDebugMode) debugPrint('Assign schedule failed: $e\n$st');
      return false;
    }
  }

  Future<bool> unassignSchedule(String id) async {
    try {
      await supabase.from('schedule_assignments').delete().eq('id', id);
      await _syncProfilesAndSchedule();
      return true;
    } catch (e, st) {
      if (kDebugMode) debugPrint('Unassign failed: $e\n$st');
      return false;
    }
  }

  // ── Song notes ────────────────────────────────────────────────────
  /// Pulls every note for one song. Called on-demand when the song detail
  /// screen opens; not part of the global startup sync (would scale badly).
  Future<void> syncSongNotes(String songId) async {
    try {
      final rows = await supabase
          .from('song_notes')
          .select(
            'id, song_id, author_id, body, created_at, profiles(display_name)',
          )
          .eq('song_id', songId)
          .order('created_at', ascending: false);
      final companions = (rows as List).map((r) {
        final m = r as Map<String, dynamic>;
        final author = m['profiles'] as Map<String, dynamic>?;
        return SongNotesCompanion.insert(
          id: m['id'] as String,
          songId: m['song_id'] as String,
          authorId: Value(m['author_id'] as String?),
          authorName: Value(author?['display_name'] as String?),
          body: m['body'] as String,
          createdAt: DateTime.parse(m['created_at'] as String),
        );
      }).toList();
      await _db.replaceSongNotes(songId, companions);
    } catch (e, st) {
      if (kDebugMode) debugPrint('Sync song notes failed: $e\n$st');
    }
  }

  Future<bool> postSongNote(String songId, String body) async {
    final user = supabase.auth.currentUser;
    if (user == null) return false;
    try {
      await supabase
          .from('song_notes')
          .insert({'song_id': songId, 'author_id': user.id, 'body': body});
      await syncSongNotes(songId);
      return true;
    } catch (e, st) {
      if (kDebugMode) debugPrint('Post song note failed: $e\n$st');
      return false;
    }
  }

  Future<bool> deleteSongNote(String songId, String id) async {
    try {
      await supabase.from('song_notes').delete().eq('id', id);
      await syncSongNotes(songId);
      return true;
    } catch (e, st) {
      if (kDebugMode) debugPrint('Delete song note failed: $e\n$st');
      return false;
    }
  }

  // ── Profile (self-update) ─────────────────────────────────────────
  Future<bool> updateMyProfile({
    required String displayName,
    List<String>? instruments,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) return false;
    try {
      await supabase.from('profiles').update({
        'display_name': displayName,
        if (instruments != null) 'instruments': instruments,
      }).eq('id', user.id);
      await _syncProfilesAndSchedule();
      return true;
    } catch (e, st) {
      if (kDebugMode) debugPrint('Update profile failed: $e\n$st');
      return false;
    }
  }

  /// Leader-only bulk insert. Returns (added, skipped) on success or null
  /// on failure. Skips by case-insensitive title match when [skipExisting]
  /// is true.
  Future<({int added, int skipped})?> bulkInsertSongs(
    List<Map<String, dynamic>> rows, {
    bool skipExisting = true,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) return null;
    try {
      var toInsert = rows;
      var skipped = 0;
      if (skipExisting && rows.isNotEmpty) {
        final titles =
            rows.map((r) => r['title'] as String).toList(growable: false);
        final existing = await supabase
            .from('songs')
            .select('title')
            .inFilter('title', titles);
        final have = (existing as List)
            .map((s) => (s as Map<String, dynamic>)['title']
                .toString()
                .toLowerCase())
            .toSet();
        final before = toInsert.length;
        toInsert = toInsert
            .where((r) =>
                !have.contains(r['title'].toString().toLowerCase()))
            .toList();
        skipped = before - toInsert.length;
      }
      if (toInsert.isNotEmpty) {
        final stamped = toInsert
            .map((r) => {...r, 'created_by': user.id})
            .toList();
        await supabase.from('songs').insert(stamped);
      }
      await _syncSongs();
      return (added: toInsert.length, skipped: skipped);
    } catch (e, st) {
      if (kDebugMode) debugPrint('Bulk insert failed: $e\n$st');
      return null;
    }
  }

  /// Leader-only — change another member's role between 'leader' / 'member'.
  Future<bool> setMemberRole(String userId, String role) async {
    try {
      await supabase.from('profiles').update({'role': role}).eq('id', userId);
      await _syncProfilesAndSchedule();
      return true;
    } catch (e, st) {
      if (kDebugMode) debugPrint('Set member role failed: $e\n$st');
      return false;
    }
  }
}

enum SyncResult { ok, skipped, failed }
