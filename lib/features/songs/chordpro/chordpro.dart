/// ChordPro parser, transposer, and view model — mirrors the behavior
/// of chordsheetjs used in the web app, but only the subset the web has
/// ever produced: title / subtitle / key / comment / start_of_X / end_of_X
/// directives, plus inline [Chord] tokens.
library;

class ParsedSong {
  ParsedSong({required this.directives, required this.sections});

  final Map<String, String> directives;
  final List<Section> sections;

  String? get title => directives['title'] ?? directives['t'];
  String? get subtitle => directives['subtitle'] ?? directives['st'];
  String? get key => directives['key'];
}

class Section {
  Section({this.label, required this.lines});

  /// e.g. "Verse 1", "Chorus" — derived from {comment} or {start_of_X}.
  final String? label;
  final List<ChordLine> lines;
}

class ChordLine {
  ChordLine(this.segments);

  /// Each segment carries an optional chord and the lyric text that follows
  /// the chord (until the next chord or end of line). For a chord-only line,
  /// segments will have non-null chord and empty text.
  final List<ChordLyric> segments;

  /// Returns true if the line has no chords and no lyric text.
  bool get isBlank =>
      segments.isEmpty ||
      segments.every((s) => (s.chord ?? '').isEmpty && s.text.isEmpty);

  /// Returns true if every segment is chord-only (no lyric text).
  bool get isChordsOnly =>
      segments.isNotEmpty && segments.every((s) => s.text.isEmpty);
}

class ChordLyric {
  ChordLyric({this.chord, this.text = ''});
  String? chord;
  String text;
}

class ChordPro {
  static final _directiveRe = RegExp(r'^\{([^:}]+)(?::\s*(.*?))?\}\s*$');
  static final _inlineChordRe = RegExp(r'\[([^\]]+)\]');

  static ParsedSong parse(String input) {
    final directives = <String, String>{};
    final sections = <Section>[];
    String? currentLabel;
    var currentLines = <ChordLine>[];

    void flush() {
      if (currentLines.isNotEmpty || currentLabel != null) {
        sections.add(Section(label: currentLabel, lines: currentLines));
        currentLabel = null;
        currentLines = [];
      }
    }

    for (final raw in input.split('\n')) {
      final line = raw.replaceAll('\r', '');
      final m = _directiveRe.firstMatch(line.trim());
      if (m != null) {
        final name = m.group(1)!.trim().toLowerCase();
        final value = (m.group(2) ?? '').trim();
        if (name == 'comment' || name == 'c') {
          flush();
          currentLabel = value;
          continue;
        }
        if (name.startsWith('start_of_')) {
          flush();
          currentLabel = _humanizeSection(name.substring('start_of_'.length));
          continue;
        }
        if (name.startsWith('end_of_')) {
          flush();
          continue;
        }
        // Metadata directive — record and don't render as a line.
        directives[name] = value;
        continue;
      }

      currentLines.add(_parseLine(line));
    }
    flush();

    if (sections.isEmpty) {
      sections.add(Section(lines: const []));
    }
    return ParsedSong(directives: directives, sections: sections);
  }

  static ChordLine _parseLine(String line) {
    if (line.isEmpty) return ChordLine([ChordLyric()]);
    final segments = <ChordLyric>[];
    var cursor = 0;
    for (final m in _inlineChordRe.allMatches(line)) {
      if (m.start > cursor) {
        // Text before this chord — attach to the previous chord (or as a
        // leading bare-text segment).
        final lead = line.substring(cursor, m.start);
        if (segments.isEmpty) {
          segments.add(ChordLyric(text: lead));
        } else {
          segments.last.text += lead;
        }
      }
      segments.add(ChordLyric(chord: m.group(1)));
      cursor = m.end;
    }
    if (cursor < line.length) {
      final tail = line.substring(cursor);
      if (segments.isEmpty) {
        segments.add(ChordLyric(text: tail));
      } else {
        segments.last.text += tail;
      }
    }
    return ChordLine(segments);
  }

  static String _humanizeSection(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1).replaceAll('_', ' ');
  }

  /// Returns a new ParsedSong with every chord transposed by [semitones].
  /// Positive = up, negative = down.
  static ParsedSong transpose(ParsedSong song, int semitones) {
    if (semitones == 0) return song;
    final useFlats = _shouldPreferFlats(song);
    final newSections = song.sections.map((sec) {
      final newLines = sec.lines.map((line) {
        final newSegs = line.segments.map((seg) {
          final c = seg.chord;
          return ChordLyric(
            chord: c == null ? null : transposeChord(c, semitones, useFlats),
            text: seg.text,
          );
        }).toList();
        return ChordLine(newSegs);
      }).toList();
      return Section(label: sec.label, lines: newLines);
    }).toList();

    final newDirectives = Map<String, String>.from(song.directives);
    final oldKey = newDirectives['key'];
    if (oldKey != null && oldKey.isNotEmpty) {
      newDirectives['key'] = transposeChord(oldKey, semitones, useFlats);
    }
    return ParsedSong(directives: newDirectives, sections: newSections);
  }

  static bool _shouldPreferFlats(ParsedSong song) {
    final key = song.directives['key'] ?? '';
    if (_flatKeys.contains(key)) return true;
    if (_sharpKeys.contains(key)) return false;
    // Scan chord tokens — if more flats than sharps, prefer flats.
    var flats = 0, sharps = 0;
    for (final sec in song.sections) {
      for (final line in sec.lines) {
        for (final seg in line.segments) {
          final c = seg.chord ?? '';
          if (c.contains('b') || c.contains('♭')) flats++;
          if (c.contains('#') || c.contains('♯')) sharps++;
        }
      }
    }
    return flats > sharps;
  }

  // ── Transposition primitives ───────────────────────────────────────────
  static const _sharpScale = [
    'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B',
  ];
  static const _flatScale = [
    'C', 'Db', 'D', 'Eb', 'E', 'F', 'Gb', 'G', 'Ab', 'A', 'Bb', 'B',
  ];
  static const _flatKeys = {
    'F', 'Bb', 'Eb', 'Ab', 'Db', 'Gb', 'Cb',
    'Dm', 'Gm', 'Cm', 'Fm', 'Bbm', 'Ebm', 'Abm',
  };
  static const _sharpKeys = {
    'G', 'D', 'A', 'E', 'B', 'F#', 'C#',
    'Em', 'Bm', 'F#m', 'C#m', 'G#m', 'D#m', 'A#m',
  };

  /// Transpose a single chord token (e.g. "G", "Am", "F#m7", "G/B").
  /// Returns the original string unchanged if the token isn't a recognizable
  /// chord (e.g. "N.C.", "Repeat", lowercase notes, etc.).
  static String transposeChord(String chord, int semitones, bool useFlats) {
    if (chord.isEmpty) return chord;
    final slash = chord.indexOf('/');
    if (slash != -1) {
      final root = transposeChord(chord.substring(0, slash), semitones, useFlats);
      final bass = transposeChord(chord.substring(slash + 1), semitones, useFlats);
      return '$root/$bass';
    }
    final parsed = _parseRoot(chord);
    if (parsed == null) return chord;
    final (rootIdx, suffix) = parsed;
    final newIdx = ((rootIdx + semitones) % 12 + 12) % 12;
    final newRoot = useFlats ? _flatScale[newIdx] : _sharpScale[newIdx];
    return '$newRoot$suffix';
  }

  static (int, String)? _parseRoot(String chord) {
    if (chord.isEmpty) return null;
    final first = chord[0];
    if (first.codeUnitAt(0) < 'A'.codeUnitAt(0) ||
        first.codeUnitAt(0) > 'G'.codeUnitAt(0)) {
      return null;
    }
    var rootStr = first;
    var i = 1;
    if (i < chord.length) {
      final accidental = chord[i];
      if (accidental == '#' || accidental == '♯') {
        rootStr += '#';
        i++;
      } else if (accidental == 'b' || accidental == '♭') {
        rootStr += 'b';
        i++;
      }
    }
    final idx = _noteIndex(rootStr);
    if (idx == null) return null;
    return (idx, chord.substring(i));
  }

  static int? _noteIndex(String note) {
    final sharpIdx = _sharpScale.indexOf(note);
    if (sharpIdx != -1) return sharpIdx;
    final flatIdx = _flatScale.indexOf(note);
    if (flatIdx != -1) return flatIdx;
    return null;
  }
}
