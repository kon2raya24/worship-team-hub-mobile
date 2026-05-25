import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_db.g.dart';

/// Mirrors `public.songs` from the web Supabase schema.
/// All IDs are UUID strings from Postgres.
@DataClassName('SongRow')
class Songs extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get artist => text().nullable()();
  TextColumn get originalKey => text().nullable()();
  IntColumn get bpm => integer().nullable()();
  TextColumn get tagsCsv => text().withDefault(const Constant(''))();
  TextColumn get chordproBody => text().withDefault(const Constant(''))();
  TextColumn get referenceUrl => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Mirrors `public.setlists`.
@DataClassName('SetlistRow')
class Setlists extends Table {
  TextColumn get id => text()();
  DateTimeColumn get serviceDate => dateTime()();
  TextColumn get theme => text().nullable()();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Mirrors `public.setlist_songs` (join table).
@DataClassName('SetlistSongRow')
class SetlistSongs extends Table {
  TextColumn get setlistId => text()();
  TextColumn get songId => text()();
  TextColumn get playedInKey => text().nullable()();
  IntColumn get position => integer()();

  @override
  Set<Column> get primaryKey => {setlistId, songId};
}

@DriftDatabase(tables: [Songs, Setlists, SetlistSongs])
class AppDb extends _$AppDb {
  AppDb() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // ── Songs ────────────────────────────────────────────────────────────
  Stream<List<SongRow>> watchAllSongs() =>
      (select(songs)..orderBy([(t) => OrderingTerm.asc(t.title)])).watch();

  Future<SongRow?> getSong(String id) =>
      (select(songs)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> upsertSongs(List<SongsCompanion> rows) async {
    if (rows.isEmpty) return;
    await batch((b) {
      for (final row in rows) {
        b.insert(songs, row, mode: InsertMode.insertOrReplace);
      }
    });
  }

  // ── Setlists ─────────────────────────────────────────────────────────
  Stream<List<SetlistRow>> watchUpcomingSetlists() {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    return (select(setlists)
          ..where((t) => t.serviceDate.isBiggerOrEqualValue(startOfDay))
          ..orderBy([(t) => OrderingTerm.asc(t.serviceDate)]))
        .watch();
  }

  Future<void> upsertSetlists(List<SetlistsCompanion> rows) async {
    if (rows.isEmpty) return;
    await batch((b) {
      for (final row in rows) {
        b.insert(setlists, row, mode: InsertMode.insertOrReplace);
      }
    });
  }

  // ── Setlist songs ────────────────────────────────────────────────────
  Future<List<SetlistSongRow>> getSetlistSongs(String setlistId) {
    return (select(setlistSongs)
          ..where((t) => t.setlistId.equals(setlistId))
          ..orderBy([(t) => OrderingTerm.asc(t.position)]))
        .get();
  }

  /// Replace-all semantics: we wipe rows for this setlist then insert the
  /// fresh server snapshot. Cheaper than diffing and idempotent.
  Future<void> replaceSetlistSongs(
    String setlistId,
    List<SetlistSongsCompanion> rows,
  ) async {
    await transaction(() async {
      await (delete(setlistSongs)..where((t) => t.setlistId.equals(setlistId)))
          .go();
      if (rows.isEmpty) return;
      await batch((b) {
        b.insertAll(setlistSongs, rows);
      });
    });
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'worship_team_hub.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
