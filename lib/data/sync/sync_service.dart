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
      await Future.wait([_syncSongs(), _syncSetlistsAndJoins()]);
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
    await _db.upsertSongs(companions);
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

    await _db.upsertSetlists(setlistCompanions);
    for (final entry in perSetlistSongs.entries) {
      await _db.replaceSetlistSongs(entry.key, entry.value);
    }
  }
}

enum SyncResult { ok, skipped, failed }
