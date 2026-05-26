// Constants + helpers for the music-theory mini-games. Mirrors the
// web app's lib/music.ts so questions feel the same across platforms.

import 'dart:math';

import '../songs/chordpro/chordpro.dart';

class Progression {
  const Progression({required this.name, required this.chords});
  final String name;
  final List<String> chords; // in C major
}

const progressions = <Progression>[
  Progression(name: 'I-V-vi-IV (4-chord)', chords: ['C', 'G', 'Am', 'F']),
  Progression(name: 'I-vi-IV-V (50s)', chords: ['C', 'Am', 'F', 'G']),
  Progression(name: 'vi-IV-I-V', chords: ['Am', 'F', 'C', 'G']),
  Progression(name: 'I-IV-V (basic)', chords: ['C', 'F', 'G']),
  Progression(name: 'I-V-vi-iii-IV (canon)', chords: ['C', 'G', 'Am', 'Em', 'F']),
  Progression(name: 'ii-V-I', chords: ['Dm', 'G', 'C']),
  Progression(name: 'I-iii-IV-V', chords: ['C', 'Em', 'F', 'G']),
];

const keysForTranspose = ['G', 'D', 'A', 'E', 'F', 'Bb', 'Eb', 'C'];

class KeySignature {
  const KeySignature({this.sharps = const [], this.flats = const []});
  final List<String> sharps;
  final List<String> flats;
  int get accidentalCount => sharps.length + flats.length;
  bool get usesFlats => flats.isNotEmpty;
}

const keySignatures = <String, KeySignature>{
  'C': KeySignature(),
  'G': KeySignature(sharps: ['F#']),
  'D': KeySignature(sharps: ['F#', 'C#']),
  'A': KeySignature(sharps: ['F#', 'C#', 'G#']),
  'E': KeySignature(sharps: ['F#', 'C#', 'G#', 'D#']),
  'B': KeySignature(sharps: ['F#', 'C#', 'G#', 'D#', 'A#']),
  'F#': KeySignature(sharps: ['F#', 'C#', 'G#', 'D#', 'A#', 'E#']),
  'F': KeySignature(flats: ['Bb']),
  'Bb': KeySignature(flats: ['Bb', 'Eb']),
  'Eb': KeySignature(flats: ['Bb', 'Eb', 'Ab']),
  'Ab': KeySignature(flats: ['Bb', 'Eb', 'Ab', 'Db']),
  'Db': KeySignature(flats: ['Bb', 'Eb', 'Ab', 'Db', 'Gb']),
};

bool keyUsesFlats(String key) => keySignatures[key]?.usesFlats ?? false;

final _rand = Random();

T pickOne<T>(List<T> list) => list[_rand.nextInt(list.length)];

List<T> pickN<T>(List<T> source, int n) {
  final copy = [...source];
  final out = <T>[];
  while (out.length < n && copy.isNotEmpty) {
    out.add(copy.removeAt(_rand.nextInt(copy.length)));
  }
  return out;
}

/// Normalise user-entered chord text so comparisons aren't tripped up
/// by casing or unicode flat/sharp variants.
String normaliseChord(String input) {
  var s = input.trim().replaceAll(RegExp(r'\s+'), '');
  if (s.isEmpty) return s;
  s = s.replaceAll('♭', 'b').replaceAll('♯', '#');
  s = s[0].toUpperCase() + s.substring(1);
  return s;
}

bool chordsEqual(String a, String b) {
  final na = normaliseChord(a);
  final nb = normaliseChord(b);
  if (na == nb) return true;
  // Same enharmonic pitch class + same suffix counts as equal.
  final ra = _splitChord(na);
  final rb = _splitChord(nb);
  if (ra == null || rb == null) return false;
  return _noteIdx(ra.root) == _noteIdx(rb.root) && ra.suffix == rb.suffix;
}

class _Parsed {
  const _Parsed(this.root, this.suffix);
  final String root;
  final String suffix;
}

_Parsed? _splitChord(String s) {
  if (s.isEmpty) return null;
  final first = s[0];
  if (first.codeUnitAt(0) < 'A'.codeUnitAt(0) ||
      first.codeUnitAt(0) > 'G'.codeUnitAt(0)) {
    return null;
  }
  var root = first;
  var i = 1;
  if (i < s.length && (s[i] == '#' || s[i] == 'b')) {
    root += s[i];
    i++;
  }
  return _Parsed(root, s.substring(i));
}

const _sharpScale = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
const _flatScale = ['C', 'Db', 'D', 'Eb', 'E', 'F', 'Gb', 'G', 'Ab', 'A', 'Bb', 'B'];

int? _noteIdx(String note) {
  final s = _sharpScale.indexOf(note);
  if (s != -1) return s;
  final f = _flatScale.indexOf(note);
  if (f != -1) return f;
  return null;
}

/// Convenience re-export of ChordPro.transposeChord so games don't have to
/// import from the chord viewer module directly.
String transposeChordInKey(String chord, int semitones, bool useFlats) =>
    ChordPro.transposeChord(chord, semitones, useFlats);

// ─── Roman numerals / diatonic chords ─────────────────────────────────────

const _majorScaleSemitones = [0, 2, 4, 5, 7, 9, 11];
const _diatonicQuality = ['', 'm', 'm', '', '', 'm', 'dim'];

/// Nashville / Roman numerals for the 7 diatonic chords of a major key.
const romanNumerals = ['I', 'ii', 'iii', 'IV', 'V', 'vi', 'vii°'];

/// Diatonic chord at scale degree (0..6) of a major key. E.g. G + 4 → D.
String diatonicChord(String key, int degree) {
  final useFlats = keyUsesFlats(key);
  final root = ChordPro.transposeChord(key, _majorScaleSemitones[degree], useFlats);
  return '$root${_diatonicQuality[degree]}';
}

// ─── Relative major / minor ───────────────────────────────────────────────

/// Relative minor of a major key (a minor 3rd below the major).
String relativeMinor(String majorKey) {
  final useFlats = keyUsesFlats(majorKey);
  return '${ChordPro.transposeChord(majorKey, -3, useFlats)}m';
}

/// Relative major from a minor key. Strips an optional "m" suffix.
String relativeMajor(String minorKey) {
  final base =
      minorKey.endsWith('m') ? minorKey.substring(0, minorKey.length - 1) : minorKey;
  final flatMajor = ChordPro.transposeChord(base, 3, true);
  if (keySignatures.containsKey(flatMajor) &&
      keySignatures[flatMajor]!.usesFlats) {
    return flatMajor;
  }
  return ChordPro.transposeChord(base, 3, false);
}

// ─── Intervals ────────────────────────────────────────────────────────────

class MusicInterval {
  const MusicInterval({required this.name, required this.short, required this.semitones});
  final String name;
  final String short;
  final int semitones;
}

/// Worship-friendly interval set — skips tritone/m2 since they rarely
/// matter for chord/voice-leading cues.
const intervals = <MusicInterval>[
  MusicInterval(name: 'Major 2nd', short: 'M2', semitones: 2),
  MusicInterval(name: 'Minor 3rd', short: 'm3', semitones: 3),
  MusicInterval(name: 'Major 3rd', short: 'M3', semitones: 4),
  MusicInterval(name: 'Perfect 4th', short: 'P4', semitones: 5),
  MusicInterval(name: 'Perfect 5th', short: 'P5', semitones: 7),
  MusicInterval(name: 'Minor 6th', short: 'm6', semitones: 8),
  MusicInterval(name: 'Major 6th', short: 'M6', semitones: 9),
  MusicInterval(name: 'Minor 7th', short: 'm7', semitones: 10),
  MusicInterval(name: 'Major 7th', short: 'M7', semitones: 11),
  MusicInterval(name: 'Octave', short: 'P8', semitones: 12),
];

/// Note `semitones` above `from`, using flat spellings if `useFlats`.
String noteAbove(String from, int semitones, {bool useFlats = false}) =>
    ChordPro.transposeChord(from, semitones, useFlats);

// ─── Capo helpers ─────────────────────────────────────────────────────────

/// Sounding key when [shape] is played with capo at fret [capo]. Re-spells
/// A# → Bb, D# → Eb, etc. so the answer reads like a worship band would
/// call it.
String shapeWithCapo(String shape, int capo) {
  final sharp = ChordPro.transposeChord(shape, capo, false);
  if (keySignatures.containsKey(sharp) && !keyUsesFlats(sharp)) return sharp;
  return ChordPro.transposeChord(shape, capo, true);
}
