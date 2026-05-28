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

/// Mirrors `public.profiles` — just the bits we need offline (name + role).
@DataClassName('ProfileRow')
class Profiles extends Table {
  TextColumn get id => text()();
  TextColumn get displayName => text()();
  TextColumn get role => text().withDefault(const Constant('member'))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Mirrors `public.schedule_assignments`.
@DataClassName('ScheduleAssignmentRow')
class ScheduleAssignments extends Table {
  TextColumn get id => text()();
  DateTimeColumn get serviceDate => dateTime()();
  TextColumn get userId => text()();
  TextColumn get role => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('DevotionRow')
class Devotions extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get body => text()();
  TextColumn get scriptureRef => text().nullable()();
  DateTimeColumn get publishedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('PrayerRequestRow')
class PrayerRequests extends Table {
  TextColumn get id => text()();
  TextColumn get authorId => text().nullable()();
  TextColumn get authorName => text().nullable()();
  TextColumn get body => text()();
  BoolColumn get isAnswered => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('AnnouncementRow')
class Announcements extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get body => text()();
  BoolColumn get pinned => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Mirrors `public.song_notes`.
@DataClassName('SongNoteRow')
class SongNotes extends Table {
  TextColumn get id => text()();
  TextColumn get songId => text()();
  TextColumn get authorId => text().nullable()();
  TextColumn get authorName => text().nullable()();
  TextColumn get body => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    Songs,
    Setlists,
    SetlistSongs,
    Profiles,
    ScheduleAssignments,
    Devotions,
    PrayerRequests,
    Announcements,
    SongNotes,
  ],
)
class AppDb extends _$AppDb {
  AppDb() : super(_openConnection());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(profiles);
            await m.createTable(scheduleAssignments);
          }
          if (from < 3) {
            await m.createTable(devotions);
            await m.createTable(prayerRequests);
            await m.createTable(announcements);
          }
          if (from < 4) {
            await m.createTable(songNotes);
          }
        },
      );

  // ── Songs ────────────────────────────────────────────────────────────
  Stream<List<SongRow>> watchAllSongs() =>
      (select(songs)..orderBy([(t) => OrderingTerm.asc(t.title)])).watch();

  Future<SongRow?> getSong(String id) =>
      (select(songs)..where((t) => t.id.equals(id))).getSingleOrNull();

  // Replace, not upsert, so songs deleted on the server are removed locally.
  // _syncSongs pulls the full library, so the pulled set is authoritative.
  Future<void> replaceSongs(List<SongsCompanion> rows) async {
    await transaction(() async {
      await delete(songs).go();
      if (rows.isEmpty) return;
      await batch((b) => b.insertAll(songs, rows));
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

  // Replace the upcoming-setlist set so deleted (and now-past) setlists drop
  // out. Per-setlist songs are reconciled separately by replaceSetlistSongs.
  Future<void> replaceSetlists(List<SetlistsCompanion> rows) async {
    await transaction(() async {
      await delete(setlists).go();
      if (rows.isEmpty) return;
      await batch((b) => b.insertAll(setlists, rows));
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

  // ── Profiles ─────────────────────────────────────────────────────────
  Future<ProfileRow?> getProfile(String id) =>
      (select(profiles)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> replaceProfiles(List<ProfilesCompanion> rows) async {
    await transaction(() async {
      await delete(profiles).go();
      if (rows.isEmpty) return;
      await batch((b) => b.insertAll(profiles, rows));
    });
  }

  Future<List<ProfileRow>> allProfiles() =>
      (select(profiles)..orderBy([(t) => OrderingTerm.asc(t.displayName)]))
          .get();

  // ── Song notes ───────────────────────────────────────────────────────
  Stream<List<SongNoteRow>> watchSongNotes(String songId) =>
      (select(songNotes)
            ..where((t) => t.songId.equals(songId))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .watch();

  Future<void> upsertSongNotes(List<SongNotesCompanion> rows) async {
    if (rows.isEmpty) return;
    await batch((b) {
      for (final row in rows) {
        b.insert(songNotes, row, mode: InsertMode.insertOrReplace);
      }
    });
  }

  Future<void> replaceSongNotes(
    String songId,
    List<SongNotesCompanion> rows,
  ) async {
    await transaction(() async {
      await (delete(songNotes)..where((t) => t.songId.equals(songId))).go();
      if (rows.isEmpty) return;
      await batch((b) => b.insertAll(songNotes, rows));
    });
  }

  // ── Schedule assignments ─────────────────────────────────────────────
  /// Watches upcoming assignments joined to member display name.
  Stream<List<UpcomingAssignment>> watchUpcomingAssignments() {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final query = (select(scheduleAssignments).join([
      leftOuterJoin(
        profiles,
        profiles.id.equalsExp(scheduleAssignments.userId),
      ),
    ])
      ..where(scheduleAssignments.serviceDate.isBiggerOrEqualValue(startOfDay))
      ..orderBy([
        OrderingTerm.asc(scheduleAssignments.serviceDate),
        OrderingTerm.asc(scheduleAssignments.role),
      ]));
    return query.watch().map((rows) {
      return rows.map((row) {
        final a = row.readTable(scheduleAssignments);
        final p = row.readTableOrNull(profiles);
        return UpcomingAssignment(
          assignment: a,
          memberName: p?.displayName ?? 'Member',
        );
      }).toList();
    });
  }

  Future<void> replaceUpcomingAssignments(
    List<ScheduleAssignmentsCompanion> rows,
  ) async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    await transaction(() async {
      await (delete(scheduleAssignments)
            ..where((t) => t.serviceDate.isBiggerOrEqualValue(startOfDay)))
          .go();
      if (rows.isEmpty) return;
      await batch((b) {
        b.insertAll(scheduleAssignments, rows);
      });
    });
  }
}

class UpcomingAssignment {
  UpcomingAssignment({required this.assignment, required this.memberName});
  final ScheduleAssignmentRow assignment;
  final String memberName;
}

extension AppDbReads on AppDb {
  Stream<List<DevotionRow>> watchDevotions() =>
      (select(devotions)..orderBy([(t) => OrderingTerm.desc(t.publishedAt)]))
          .watch();

  Future<DevotionRow?> getDevotion(String id) =>
      (select(devotions)..where((t) => t.id.equals(id))).getSingleOrNull();

  // Replace the cached set (not upsert) so rows deleted on the server are
  // removed locally instead of lingering forever.
  Future<void> replaceDevotions(List<DevotionsCompanion> rows) async {
    await transaction(() async {
      await delete(devotions).go();
      if (rows.isEmpty) return;
      await batch((b) => b.insertAll(devotions, rows));
    });
  }

  Stream<List<PrayerRequestRow>> watchPrayerRequests() =>
      (select(prayerRequests)
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .watch();

  Future<void> replacePrayerRequests(
    List<PrayerRequestsCompanion> rows,
  ) async {
    await transaction(() async {
      await delete(prayerRequests).go();
      if (rows.isEmpty) return;
      await batch((b) => b.insertAll(prayerRequests, rows));
    });
  }

  Stream<List<AnnouncementRow>> watchAnnouncements() =>
      (select(announcements)
            ..orderBy([
              (t) => OrderingTerm.desc(t.pinned),
              (t) => OrderingTerm.desc(t.createdAt),
            ]))
          .watch();

  Future<void> replaceAnnouncements(
    List<AnnouncementsCompanion> rows,
  ) async {
    await transaction(() async {
      await delete(announcements).go();
      if (rows.isEmpty) return;
      await batch((b) => b.insertAll(announcements, rows));
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
