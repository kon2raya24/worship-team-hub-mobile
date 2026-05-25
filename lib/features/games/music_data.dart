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
