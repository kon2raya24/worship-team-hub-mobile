// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_db.dart';

// ignore_for_file: type=lint
class $SongsTable extends Songs with TableInfo<$SongsTable, SongRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SongsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _artistMeta = const VerificationMeta('artist');
  @override
  late final GeneratedColumn<String> artist = GeneratedColumn<String>(
    'artist',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _originalKeyMeta = const VerificationMeta(
    'originalKey',
  );
  @override
  late final GeneratedColumn<String> originalKey = GeneratedColumn<String>(
    'original_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bpmMeta = const VerificationMeta('bpm');
  @override
  late final GeneratedColumn<int> bpm = GeneratedColumn<int>(
    'bpm',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tagsCsvMeta = const VerificationMeta(
    'tagsCsv',
  );
  @override
  late final GeneratedColumn<String> tagsCsv = GeneratedColumn<String>(
    'tags_csv',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _chordproBodyMeta = const VerificationMeta(
    'chordproBody',
  );
  @override
  late final GeneratedColumn<String> chordproBody = GeneratedColumn<String>(
    'chordpro_body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _referenceUrlMeta = const VerificationMeta(
    'referenceUrl',
  );
  @override
  late final GeneratedColumn<String> referenceUrl = GeneratedColumn<String>(
    'reference_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    artist,
    originalKey,
    bpm,
    tagsCsv,
    chordproBody,
    referenceUrl,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'songs';
  @override
  VerificationContext validateIntegrity(
    Insertable<SongRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('artist')) {
      context.handle(
        _artistMeta,
        artist.isAcceptableOrUnknown(data['artist']!, _artistMeta),
      );
    }
    if (data.containsKey('original_key')) {
      context.handle(
        _originalKeyMeta,
        originalKey.isAcceptableOrUnknown(
          data['original_key']!,
          _originalKeyMeta,
        ),
      );
    }
    if (data.containsKey('bpm')) {
      context.handle(
        _bpmMeta,
        bpm.isAcceptableOrUnknown(data['bpm']!, _bpmMeta),
      );
    }
    if (data.containsKey('tags_csv')) {
      context.handle(
        _tagsCsvMeta,
        tagsCsv.isAcceptableOrUnknown(data['tags_csv']!, _tagsCsvMeta),
      );
    }
    if (data.containsKey('chordpro_body')) {
      context.handle(
        _chordproBodyMeta,
        chordproBody.isAcceptableOrUnknown(
          data['chordpro_body']!,
          _chordproBodyMeta,
        ),
      );
    }
    if (data.containsKey('reference_url')) {
      context.handle(
        _referenceUrlMeta,
        referenceUrl.isAcceptableOrUnknown(
          data['reference_url']!,
          _referenceUrlMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SongRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SongRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      artist: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artist'],
      ),
      originalKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}original_key'],
      ),
      bpm: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bpm'],
      ),
      tagsCsv: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags_csv'],
      )!,
      chordproBody: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chordpro_body'],
      )!,
      referenceUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reference_url'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SongsTable createAlias(String alias) {
    return $SongsTable(attachedDatabase, alias);
  }
}

class SongRow extends DataClass implements Insertable<SongRow> {
  final String id;
  final String title;
  final String? artist;
  final String? originalKey;
  final int? bpm;
  final String tagsCsv;
  final String chordproBody;
  final String? referenceUrl;
  final DateTime updatedAt;
  const SongRow({
    required this.id,
    required this.title,
    this.artist,
    this.originalKey,
    this.bpm,
    required this.tagsCsv,
    required this.chordproBody,
    this.referenceUrl,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || artist != null) {
      map['artist'] = Variable<String>(artist);
    }
    if (!nullToAbsent || originalKey != null) {
      map['original_key'] = Variable<String>(originalKey);
    }
    if (!nullToAbsent || bpm != null) {
      map['bpm'] = Variable<int>(bpm);
    }
    map['tags_csv'] = Variable<String>(tagsCsv);
    map['chordpro_body'] = Variable<String>(chordproBody);
    if (!nullToAbsent || referenceUrl != null) {
      map['reference_url'] = Variable<String>(referenceUrl);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SongsCompanion toCompanion(bool nullToAbsent) {
    return SongsCompanion(
      id: Value(id),
      title: Value(title),
      artist: artist == null && nullToAbsent
          ? const Value.absent()
          : Value(artist),
      originalKey: originalKey == null && nullToAbsent
          ? const Value.absent()
          : Value(originalKey),
      bpm: bpm == null && nullToAbsent ? const Value.absent() : Value(bpm),
      tagsCsv: Value(tagsCsv),
      chordproBody: Value(chordproBody),
      referenceUrl: referenceUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(referenceUrl),
      updatedAt: Value(updatedAt),
    );
  }

  factory SongRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SongRow(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      artist: serializer.fromJson<String?>(json['artist']),
      originalKey: serializer.fromJson<String?>(json['originalKey']),
      bpm: serializer.fromJson<int?>(json['bpm']),
      tagsCsv: serializer.fromJson<String>(json['tagsCsv']),
      chordproBody: serializer.fromJson<String>(json['chordproBody']),
      referenceUrl: serializer.fromJson<String?>(json['referenceUrl']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'artist': serializer.toJson<String?>(artist),
      'originalKey': serializer.toJson<String?>(originalKey),
      'bpm': serializer.toJson<int?>(bpm),
      'tagsCsv': serializer.toJson<String>(tagsCsv),
      'chordproBody': serializer.toJson<String>(chordproBody),
      'referenceUrl': serializer.toJson<String?>(referenceUrl),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  SongRow copyWith({
    String? id,
    String? title,
    Value<String?> artist = const Value.absent(),
    Value<String?> originalKey = const Value.absent(),
    Value<int?> bpm = const Value.absent(),
    String? tagsCsv,
    String? chordproBody,
    Value<String?> referenceUrl = const Value.absent(),
    DateTime? updatedAt,
  }) => SongRow(
    id: id ?? this.id,
    title: title ?? this.title,
    artist: artist.present ? artist.value : this.artist,
    originalKey: originalKey.present ? originalKey.value : this.originalKey,
    bpm: bpm.present ? bpm.value : this.bpm,
    tagsCsv: tagsCsv ?? this.tagsCsv,
    chordproBody: chordproBody ?? this.chordproBody,
    referenceUrl: referenceUrl.present ? referenceUrl.value : this.referenceUrl,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  SongRow copyWithCompanion(SongsCompanion data) {
    return SongRow(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      artist: data.artist.present ? data.artist.value : this.artist,
      originalKey: data.originalKey.present
          ? data.originalKey.value
          : this.originalKey,
      bpm: data.bpm.present ? data.bpm.value : this.bpm,
      tagsCsv: data.tagsCsv.present ? data.tagsCsv.value : this.tagsCsv,
      chordproBody: data.chordproBody.present
          ? data.chordproBody.value
          : this.chordproBody,
      referenceUrl: data.referenceUrl.present
          ? data.referenceUrl.value
          : this.referenceUrl,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SongRow(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('originalKey: $originalKey, ')
          ..write('bpm: $bpm, ')
          ..write('tagsCsv: $tagsCsv, ')
          ..write('chordproBody: $chordproBody, ')
          ..write('referenceUrl: $referenceUrl, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    artist,
    originalKey,
    bpm,
    tagsCsv,
    chordproBody,
    referenceUrl,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SongRow &&
          other.id == this.id &&
          other.title == this.title &&
          other.artist == this.artist &&
          other.originalKey == this.originalKey &&
          other.bpm == this.bpm &&
          other.tagsCsv == this.tagsCsv &&
          other.chordproBody == this.chordproBody &&
          other.referenceUrl == this.referenceUrl &&
          other.updatedAt == this.updatedAt);
}

class SongsCompanion extends UpdateCompanion<SongRow> {
  final Value<String> id;
  final Value<String> title;
  final Value<String?> artist;
  final Value<String?> originalKey;
  final Value<int?> bpm;
  final Value<String> tagsCsv;
  final Value<String> chordproBody;
  final Value<String?> referenceUrl;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const SongsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.artist = const Value.absent(),
    this.originalKey = const Value.absent(),
    this.bpm = const Value.absent(),
    this.tagsCsv = const Value.absent(),
    this.chordproBody = const Value.absent(),
    this.referenceUrl = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SongsCompanion.insert({
    required String id,
    required String title,
    this.artist = const Value.absent(),
    this.originalKey = const Value.absent(),
    this.bpm = const Value.absent(),
    this.tagsCsv = const Value.absent(),
    this.chordproBody = const Value.absent(),
    this.referenceUrl = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       updatedAt = Value(updatedAt);
  static Insertable<SongRow> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? artist,
    Expression<String>? originalKey,
    Expression<int>? bpm,
    Expression<String>? tagsCsv,
    Expression<String>? chordproBody,
    Expression<String>? referenceUrl,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (artist != null) 'artist': artist,
      if (originalKey != null) 'original_key': originalKey,
      if (bpm != null) 'bpm': bpm,
      if (tagsCsv != null) 'tags_csv': tagsCsv,
      if (chordproBody != null) 'chordpro_body': chordproBody,
      if (referenceUrl != null) 'reference_url': referenceUrl,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SongsCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String?>? artist,
    Value<String?>? originalKey,
    Value<int?>? bpm,
    Value<String>? tagsCsv,
    Value<String>? chordproBody,
    Value<String?>? referenceUrl,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return SongsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      originalKey: originalKey ?? this.originalKey,
      bpm: bpm ?? this.bpm,
      tagsCsv: tagsCsv ?? this.tagsCsv,
      chordproBody: chordproBody ?? this.chordproBody,
      referenceUrl: referenceUrl ?? this.referenceUrl,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (artist.present) {
      map['artist'] = Variable<String>(artist.value);
    }
    if (originalKey.present) {
      map['original_key'] = Variable<String>(originalKey.value);
    }
    if (bpm.present) {
      map['bpm'] = Variable<int>(bpm.value);
    }
    if (tagsCsv.present) {
      map['tags_csv'] = Variable<String>(tagsCsv.value);
    }
    if (chordproBody.present) {
      map['chordpro_body'] = Variable<String>(chordproBody.value);
    }
    if (referenceUrl.present) {
      map['reference_url'] = Variable<String>(referenceUrl.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SongsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('originalKey: $originalKey, ')
          ..write('bpm: $bpm, ')
          ..write('tagsCsv: $tagsCsv, ')
          ..write('chordproBody: $chordproBody, ')
          ..write('referenceUrl: $referenceUrl, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SetlistsTable extends Setlists
    with TableInfo<$SetlistsTable, SetlistRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SetlistsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serviceDateMeta = const VerificationMeta(
    'serviceDate',
  );
  @override
  late final GeneratedColumn<DateTime> serviceDate = GeneratedColumn<DateTime>(
    'service_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _themeMeta = const VerificationMeta('theme');
  @override
  late final GeneratedColumn<String> theme = GeneratedColumn<String>(
    'theme',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, serviceDate, theme, notes];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'setlists';
  @override
  VerificationContext validateIntegrity(
    Insertable<SetlistRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('service_date')) {
      context.handle(
        _serviceDateMeta,
        serviceDate.isAcceptableOrUnknown(
          data['service_date']!,
          _serviceDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_serviceDateMeta);
    }
    if (data.containsKey('theme')) {
      context.handle(
        _themeMeta,
        theme.isAcceptableOrUnknown(data['theme']!, _themeMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SetlistRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SetlistRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      serviceDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}service_date'],
      )!,
      theme: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}theme'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
    );
  }

  @override
  $SetlistsTable createAlias(String alias) {
    return $SetlistsTable(attachedDatabase, alias);
  }
}

class SetlistRow extends DataClass implements Insertable<SetlistRow> {
  final String id;
  final DateTime serviceDate;
  final String? theme;
  final String? notes;
  const SetlistRow({
    required this.id,
    required this.serviceDate,
    this.theme,
    this.notes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['service_date'] = Variable<DateTime>(serviceDate);
    if (!nullToAbsent || theme != null) {
      map['theme'] = Variable<String>(theme);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    return map;
  }

  SetlistsCompanion toCompanion(bool nullToAbsent) {
    return SetlistsCompanion(
      id: Value(id),
      serviceDate: Value(serviceDate),
      theme: theme == null && nullToAbsent
          ? const Value.absent()
          : Value(theme),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
    );
  }

  factory SetlistRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SetlistRow(
      id: serializer.fromJson<String>(json['id']),
      serviceDate: serializer.fromJson<DateTime>(json['serviceDate']),
      theme: serializer.fromJson<String?>(json['theme']),
      notes: serializer.fromJson<String?>(json['notes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'serviceDate': serializer.toJson<DateTime>(serviceDate),
      'theme': serializer.toJson<String?>(theme),
      'notes': serializer.toJson<String?>(notes),
    };
  }

  SetlistRow copyWith({
    String? id,
    DateTime? serviceDate,
    Value<String?> theme = const Value.absent(),
    Value<String?> notes = const Value.absent(),
  }) => SetlistRow(
    id: id ?? this.id,
    serviceDate: serviceDate ?? this.serviceDate,
    theme: theme.present ? theme.value : this.theme,
    notes: notes.present ? notes.value : this.notes,
  );
  SetlistRow copyWithCompanion(SetlistsCompanion data) {
    return SetlistRow(
      id: data.id.present ? data.id.value : this.id,
      serviceDate: data.serviceDate.present
          ? data.serviceDate.value
          : this.serviceDate,
      theme: data.theme.present ? data.theme.value : this.theme,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SetlistRow(')
          ..write('id: $id, ')
          ..write('serviceDate: $serviceDate, ')
          ..write('theme: $theme, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, serviceDate, theme, notes);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SetlistRow &&
          other.id == this.id &&
          other.serviceDate == this.serviceDate &&
          other.theme == this.theme &&
          other.notes == this.notes);
}

class SetlistsCompanion extends UpdateCompanion<SetlistRow> {
  final Value<String> id;
  final Value<DateTime> serviceDate;
  final Value<String?> theme;
  final Value<String?> notes;
  final Value<int> rowid;
  const SetlistsCompanion({
    this.id = const Value.absent(),
    this.serviceDate = const Value.absent(),
    this.theme = const Value.absent(),
    this.notes = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SetlistsCompanion.insert({
    required String id,
    required DateTime serviceDate,
    this.theme = const Value.absent(),
    this.notes = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       serviceDate = Value(serviceDate);
  static Insertable<SetlistRow> custom({
    Expression<String>? id,
    Expression<DateTime>? serviceDate,
    Expression<String>? theme,
    Expression<String>? notes,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (serviceDate != null) 'service_date': serviceDate,
      if (theme != null) 'theme': theme,
      if (notes != null) 'notes': notes,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SetlistsCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? serviceDate,
    Value<String?>? theme,
    Value<String?>? notes,
    Value<int>? rowid,
  }) {
    return SetlistsCompanion(
      id: id ?? this.id,
      serviceDate: serviceDate ?? this.serviceDate,
      theme: theme ?? this.theme,
      notes: notes ?? this.notes,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (serviceDate.present) {
      map['service_date'] = Variable<DateTime>(serviceDate.value);
    }
    if (theme.present) {
      map['theme'] = Variable<String>(theme.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SetlistsCompanion(')
          ..write('id: $id, ')
          ..write('serviceDate: $serviceDate, ')
          ..write('theme: $theme, ')
          ..write('notes: $notes, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SetlistSongsTable extends SetlistSongs
    with TableInfo<$SetlistSongsTable, SetlistSongRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SetlistSongsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _setlistIdMeta = const VerificationMeta(
    'setlistId',
  );
  @override
  late final GeneratedColumn<String> setlistId = GeneratedColumn<String>(
    'setlist_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _songIdMeta = const VerificationMeta('songId');
  @override
  late final GeneratedColumn<String> songId = GeneratedColumn<String>(
    'song_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _playedInKeyMeta = const VerificationMeta(
    'playedInKey',
  );
  @override
  late final GeneratedColumn<String> playedInKey = GeneratedColumn<String>(
    'played_in_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    setlistId,
    songId,
    playedInKey,
    position,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'setlist_songs';
  @override
  VerificationContext validateIntegrity(
    Insertable<SetlistSongRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('setlist_id')) {
      context.handle(
        _setlistIdMeta,
        setlistId.isAcceptableOrUnknown(data['setlist_id']!, _setlistIdMeta),
      );
    } else if (isInserting) {
      context.missing(_setlistIdMeta);
    }
    if (data.containsKey('song_id')) {
      context.handle(
        _songIdMeta,
        songId.isAcceptableOrUnknown(data['song_id']!, _songIdMeta),
      );
    } else if (isInserting) {
      context.missing(_songIdMeta);
    }
    if (data.containsKey('played_in_key')) {
      context.handle(
        _playedInKeyMeta,
        playedInKey.isAcceptableOrUnknown(
          data['played_in_key']!,
          _playedInKeyMeta,
        ),
      );
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {setlistId, songId};
  @override
  SetlistSongRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SetlistSongRow(
      setlistId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}setlist_id'],
      )!,
      songId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}song_id'],
      )!,
      playedInKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}played_in_key'],
      ),
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
    );
  }

  @override
  $SetlistSongsTable createAlias(String alias) {
    return $SetlistSongsTable(attachedDatabase, alias);
  }
}

class SetlistSongRow extends DataClass implements Insertable<SetlistSongRow> {
  final String setlistId;
  final String songId;
  final String? playedInKey;
  final int position;
  const SetlistSongRow({
    required this.setlistId,
    required this.songId,
    this.playedInKey,
    required this.position,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['setlist_id'] = Variable<String>(setlistId);
    map['song_id'] = Variable<String>(songId);
    if (!nullToAbsent || playedInKey != null) {
      map['played_in_key'] = Variable<String>(playedInKey);
    }
    map['position'] = Variable<int>(position);
    return map;
  }

  SetlistSongsCompanion toCompanion(bool nullToAbsent) {
    return SetlistSongsCompanion(
      setlistId: Value(setlistId),
      songId: Value(songId),
      playedInKey: playedInKey == null && nullToAbsent
          ? const Value.absent()
          : Value(playedInKey),
      position: Value(position),
    );
  }

  factory SetlistSongRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SetlistSongRow(
      setlistId: serializer.fromJson<String>(json['setlistId']),
      songId: serializer.fromJson<String>(json['songId']),
      playedInKey: serializer.fromJson<String?>(json['playedInKey']),
      position: serializer.fromJson<int>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'setlistId': serializer.toJson<String>(setlistId),
      'songId': serializer.toJson<String>(songId),
      'playedInKey': serializer.toJson<String?>(playedInKey),
      'position': serializer.toJson<int>(position),
    };
  }

  SetlistSongRow copyWith({
    String? setlistId,
    String? songId,
    Value<String?> playedInKey = const Value.absent(),
    int? position,
  }) => SetlistSongRow(
    setlistId: setlistId ?? this.setlistId,
    songId: songId ?? this.songId,
    playedInKey: playedInKey.present ? playedInKey.value : this.playedInKey,
    position: position ?? this.position,
  );
  SetlistSongRow copyWithCompanion(SetlistSongsCompanion data) {
    return SetlistSongRow(
      setlistId: data.setlistId.present ? data.setlistId.value : this.setlistId,
      songId: data.songId.present ? data.songId.value : this.songId,
      playedInKey: data.playedInKey.present
          ? data.playedInKey.value
          : this.playedInKey,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SetlistSongRow(')
          ..write('setlistId: $setlistId, ')
          ..write('songId: $songId, ')
          ..write('playedInKey: $playedInKey, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(setlistId, songId, playedInKey, position);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SetlistSongRow &&
          other.setlistId == this.setlistId &&
          other.songId == this.songId &&
          other.playedInKey == this.playedInKey &&
          other.position == this.position);
}

class SetlistSongsCompanion extends UpdateCompanion<SetlistSongRow> {
  final Value<String> setlistId;
  final Value<String> songId;
  final Value<String?> playedInKey;
  final Value<int> position;
  final Value<int> rowid;
  const SetlistSongsCompanion({
    this.setlistId = const Value.absent(),
    this.songId = const Value.absent(),
    this.playedInKey = const Value.absent(),
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SetlistSongsCompanion.insert({
    required String setlistId,
    required String songId,
    this.playedInKey = const Value.absent(),
    required int position,
    this.rowid = const Value.absent(),
  }) : setlistId = Value(setlistId),
       songId = Value(songId),
       position = Value(position);
  static Insertable<SetlistSongRow> custom({
    Expression<String>? setlistId,
    Expression<String>? songId,
    Expression<String>? playedInKey,
    Expression<int>? position,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (setlistId != null) 'setlist_id': setlistId,
      if (songId != null) 'song_id': songId,
      if (playedInKey != null) 'played_in_key': playedInKey,
      if (position != null) 'position': position,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SetlistSongsCompanion copyWith({
    Value<String>? setlistId,
    Value<String>? songId,
    Value<String?>? playedInKey,
    Value<int>? position,
    Value<int>? rowid,
  }) {
    return SetlistSongsCompanion(
      setlistId: setlistId ?? this.setlistId,
      songId: songId ?? this.songId,
      playedInKey: playedInKey ?? this.playedInKey,
      position: position ?? this.position,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (setlistId.present) {
      map['setlist_id'] = Variable<String>(setlistId.value);
    }
    if (songId.present) {
      map['song_id'] = Variable<String>(songId.value);
    }
    if (playedInKey.present) {
      map['played_in_key'] = Variable<String>(playedInKey.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SetlistSongsCompanion(')
          ..write('setlistId: $setlistId, ')
          ..write('songId: $songId, ')
          ..write('playedInKey: $playedInKey, ')
          ..write('position: $position, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDb extends GeneratedDatabase {
  _$AppDb(QueryExecutor e) : super(e);
  $AppDbManager get managers => $AppDbManager(this);
  late final $SongsTable songs = $SongsTable(this);
  late final $SetlistsTable setlists = $SetlistsTable(this);
  late final $SetlistSongsTable setlistSongs = $SetlistSongsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    songs,
    setlists,
    setlistSongs,
  ];
}

typedef $$SongsTableCreateCompanionBuilder =
    SongsCompanion Function({
      required String id,
      required String title,
      Value<String?> artist,
      Value<String?> originalKey,
      Value<int?> bpm,
      Value<String> tagsCsv,
      Value<String> chordproBody,
      Value<String?> referenceUrl,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$SongsTableUpdateCompanionBuilder =
    SongsCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String?> artist,
      Value<String?> originalKey,
      Value<int?> bpm,
      Value<String> tagsCsv,
      Value<String> chordproBody,
      Value<String?> referenceUrl,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$SongsTableFilterComposer extends Composer<_$AppDb, $SongsTable> {
  $$SongsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artist => $composableBuilder(
    column: $table.artist,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originalKey => $composableBuilder(
    column: $table.originalKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bpm => $composableBuilder(
    column: $table.bpm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tagsCsv => $composableBuilder(
    column: $table.tagsCsv,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chordproBody => $composableBuilder(
    column: $table.chordproBody,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get referenceUrl => $composableBuilder(
    column: $table.referenceUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SongsTableOrderingComposer extends Composer<_$AppDb, $SongsTable> {
  $$SongsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artist => $composableBuilder(
    column: $table.artist,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originalKey => $composableBuilder(
    column: $table.originalKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bpm => $composableBuilder(
    column: $table.bpm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tagsCsv => $composableBuilder(
    column: $table.tagsCsv,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chordproBody => $composableBuilder(
    column: $table.chordproBody,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get referenceUrl => $composableBuilder(
    column: $table.referenceUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SongsTableAnnotationComposer extends Composer<_$AppDb, $SongsTable> {
  $$SongsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get artist =>
      $composableBuilder(column: $table.artist, builder: (column) => column);

  GeneratedColumn<String> get originalKey => $composableBuilder(
    column: $table.originalKey,
    builder: (column) => column,
  );

  GeneratedColumn<int> get bpm =>
      $composableBuilder(column: $table.bpm, builder: (column) => column);

  GeneratedColumn<String> get tagsCsv =>
      $composableBuilder(column: $table.tagsCsv, builder: (column) => column);

  GeneratedColumn<String> get chordproBody => $composableBuilder(
    column: $table.chordproBody,
    builder: (column) => column,
  );

  GeneratedColumn<String> get referenceUrl => $composableBuilder(
    column: $table.referenceUrl,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SongsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $SongsTable,
          SongRow,
          $$SongsTableFilterComposer,
          $$SongsTableOrderingComposer,
          $$SongsTableAnnotationComposer,
          $$SongsTableCreateCompanionBuilder,
          $$SongsTableUpdateCompanionBuilder,
          (SongRow, BaseReferences<_$AppDb, $SongsTable, SongRow>),
          SongRow,
          PrefetchHooks Function()
        > {
  $$SongsTableTableManager(_$AppDb db, $SongsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SongsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SongsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SongsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> artist = const Value.absent(),
                Value<String?> originalKey = const Value.absent(),
                Value<int?> bpm = const Value.absent(),
                Value<String> tagsCsv = const Value.absent(),
                Value<String> chordproBody = const Value.absent(),
                Value<String?> referenceUrl = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SongsCompanion(
                id: id,
                title: title,
                artist: artist,
                originalKey: originalKey,
                bpm: bpm,
                tagsCsv: tagsCsv,
                chordproBody: chordproBody,
                referenceUrl: referenceUrl,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                Value<String?> artist = const Value.absent(),
                Value<String?> originalKey = const Value.absent(),
                Value<int?> bpm = const Value.absent(),
                Value<String> tagsCsv = const Value.absent(),
                Value<String> chordproBody = const Value.absent(),
                Value<String?> referenceUrl = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => SongsCompanion.insert(
                id: id,
                title: title,
                artist: artist,
                originalKey: originalKey,
                bpm: bpm,
                tagsCsv: tagsCsv,
                chordproBody: chordproBody,
                referenceUrl: referenceUrl,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SongsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $SongsTable,
      SongRow,
      $$SongsTableFilterComposer,
      $$SongsTableOrderingComposer,
      $$SongsTableAnnotationComposer,
      $$SongsTableCreateCompanionBuilder,
      $$SongsTableUpdateCompanionBuilder,
      (SongRow, BaseReferences<_$AppDb, $SongsTable, SongRow>),
      SongRow,
      PrefetchHooks Function()
    >;
typedef $$SetlistsTableCreateCompanionBuilder =
    SetlistsCompanion Function({
      required String id,
      required DateTime serviceDate,
      Value<String?> theme,
      Value<String?> notes,
      Value<int> rowid,
    });
typedef $$SetlistsTableUpdateCompanionBuilder =
    SetlistsCompanion Function({
      Value<String> id,
      Value<DateTime> serviceDate,
      Value<String?> theme,
      Value<String?> notes,
      Value<int> rowid,
    });

class $$SetlistsTableFilterComposer extends Composer<_$AppDb, $SetlistsTable> {
  $$SetlistsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get serviceDate => $composableBuilder(
    column: $table.serviceDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get theme => $composableBuilder(
    column: $table.theme,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SetlistsTableOrderingComposer
    extends Composer<_$AppDb, $SetlistsTable> {
  $$SetlistsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get serviceDate => $composableBuilder(
    column: $table.serviceDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get theme => $composableBuilder(
    column: $table.theme,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SetlistsTableAnnotationComposer
    extends Composer<_$AppDb, $SetlistsTable> {
  $$SetlistsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get serviceDate => $composableBuilder(
    column: $table.serviceDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get theme =>
      $composableBuilder(column: $table.theme, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);
}

class $$SetlistsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $SetlistsTable,
          SetlistRow,
          $$SetlistsTableFilterComposer,
          $$SetlistsTableOrderingComposer,
          $$SetlistsTableAnnotationComposer,
          $$SetlistsTableCreateCompanionBuilder,
          $$SetlistsTableUpdateCompanionBuilder,
          (SetlistRow, BaseReferences<_$AppDb, $SetlistsTable, SetlistRow>),
          SetlistRow,
          PrefetchHooks Function()
        > {
  $$SetlistsTableTableManager(_$AppDb db, $SetlistsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SetlistsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SetlistsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SetlistsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> serviceDate = const Value.absent(),
                Value<String?> theme = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SetlistsCompanion(
                id: id,
                serviceDate: serviceDate,
                theme: theme,
                notes: notes,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required DateTime serviceDate,
                Value<String?> theme = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SetlistsCompanion.insert(
                id: id,
                serviceDate: serviceDate,
                theme: theme,
                notes: notes,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SetlistsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $SetlistsTable,
      SetlistRow,
      $$SetlistsTableFilterComposer,
      $$SetlistsTableOrderingComposer,
      $$SetlistsTableAnnotationComposer,
      $$SetlistsTableCreateCompanionBuilder,
      $$SetlistsTableUpdateCompanionBuilder,
      (SetlistRow, BaseReferences<_$AppDb, $SetlistsTable, SetlistRow>),
      SetlistRow,
      PrefetchHooks Function()
    >;
typedef $$SetlistSongsTableCreateCompanionBuilder =
    SetlistSongsCompanion Function({
      required String setlistId,
      required String songId,
      Value<String?> playedInKey,
      required int position,
      Value<int> rowid,
    });
typedef $$SetlistSongsTableUpdateCompanionBuilder =
    SetlistSongsCompanion Function({
      Value<String> setlistId,
      Value<String> songId,
      Value<String?> playedInKey,
      Value<int> position,
      Value<int> rowid,
    });

class $$SetlistSongsTableFilterComposer
    extends Composer<_$AppDb, $SetlistSongsTable> {
  $$SetlistSongsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get setlistId => $composableBuilder(
    column: $table.setlistId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get songId => $composableBuilder(
    column: $table.songId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get playedInKey => $composableBuilder(
    column: $table.playedInKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SetlistSongsTableOrderingComposer
    extends Composer<_$AppDb, $SetlistSongsTable> {
  $$SetlistSongsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get setlistId => $composableBuilder(
    column: $table.setlistId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get songId => $composableBuilder(
    column: $table.songId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get playedInKey => $composableBuilder(
    column: $table.playedInKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SetlistSongsTableAnnotationComposer
    extends Composer<_$AppDb, $SetlistSongsTable> {
  $$SetlistSongsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get setlistId =>
      $composableBuilder(column: $table.setlistId, builder: (column) => column);

  GeneratedColumn<String> get songId =>
      $composableBuilder(column: $table.songId, builder: (column) => column);

  GeneratedColumn<String> get playedInKey => $composableBuilder(
    column: $table.playedInKey,
    builder: (column) => column,
  );

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);
}

class $$SetlistSongsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $SetlistSongsTable,
          SetlistSongRow,
          $$SetlistSongsTableFilterComposer,
          $$SetlistSongsTableOrderingComposer,
          $$SetlistSongsTableAnnotationComposer,
          $$SetlistSongsTableCreateCompanionBuilder,
          $$SetlistSongsTableUpdateCompanionBuilder,
          (
            SetlistSongRow,
            BaseReferences<_$AppDb, $SetlistSongsTable, SetlistSongRow>,
          ),
          SetlistSongRow,
          PrefetchHooks Function()
        > {
  $$SetlistSongsTableTableManager(_$AppDb db, $SetlistSongsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SetlistSongsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SetlistSongsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SetlistSongsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> setlistId = const Value.absent(),
                Value<String> songId = const Value.absent(),
                Value<String?> playedInKey = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SetlistSongsCompanion(
                setlistId: setlistId,
                songId: songId,
                playedInKey: playedInKey,
                position: position,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String setlistId,
                required String songId,
                Value<String?> playedInKey = const Value.absent(),
                required int position,
                Value<int> rowid = const Value.absent(),
              }) => SetlistSongsCompanion.insert(
                setlistId: setlistId,
                songId: songId,
                playedInKey: playedInKey,
                position: position,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SetlistSongsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $SetlistSongsTable,
      SetlistSongRow,
      $$SetlistSongsTableFilterComposer,
      $$SetlistSongsTableOrderingComposer,
      $$SetlistSongsTableAnnotationComposer,
      $$SetlistSongsTableCreateCompanionBuilder,
      $$SetlistSongsTableUpdateCompanionBuilder,
      (
        SetlistSongRow,
        BaseReferences<_$AppDb, $SetlistSongsTable, SetlistSongRow>,
      ),
      SetlistSongRow,
      PrefetchHooks Function()
    >;

class $AppDbManager {
  final _$AppDb _db;
  $AppDbManager(this._db);
  $$SongsTableTableManager get songs =>
      $$SongsTableTableManager(_db, _db.songs);
  $$SetlistsTableTableManager get setlists =>
      $$SetlistsTableTableManager(_db, _db.setlists);
  $$SetlistSongsTableTableManager get setlistSongs =>
      $$SetlistSongsTableTableManager(_db, _db.setlistSongs);
}
