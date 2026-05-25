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

@DriftDatabase(
  tables: [Songs, Setlists, SetlistSongs, Profiles, ScheduleAssignments],
)
class AppDb extends _$AppDb {
  AppDb() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(profiles);
            await m.createTable(scheduleAssignments);
          }
        },
      );

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

  // ── Profiles ─────────────────────────────────────────────────────────
  Future<ProfileRow?> getProfile(String id) =>
      (select(profiles)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> upsertProfiles(List<ProfilesCompanion> rows) async {
    if (rows.isEmpty) return;
    await batch((b) {
      for (final row in rows) {
        b.insert(profiles, row, mode: InsertMode.insertOrReplace);
      }
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

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'worship_team_hub.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
