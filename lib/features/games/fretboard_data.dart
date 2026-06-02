// Scale + fretboard engine for the Fretboard Explorer (visual-only v1).
// Ported 1:1 from the web app's lib/fretboard.ts so both platforms stay in
// sync. Pure data/geometry — no audio, no Flutter imports.

const List<String> _sharpNames = [
  'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B',
];
const List<String> _flatNames = [
  'C', 'Db', 'D', 'Eb', 'E', 'F', 'Gb', 'G', 'Ab', 'A', 'Bb', 'B',
];

/// Pitch class (0-11) for a note name; null if unrecognized.
int? pitchClass(String note) {
  final s = _sharpNames.indexOf(note);
  if (s != -1) return s;
  final f = _flatNames.indexOf(note);
  if (f != -1) return f;
  return null;
}

/// Roots offered in the picker — guitar-idiomatic enharmonic spellings.
const List<String> kRoots = [
  'C', 'C#', 'D', 'Eb', 'E', 'F', 'F#', 'G', 'Ab', 'A', 'Bb', 'B',
];

/// Roots whose key signatures use flats (so accidentals read naturally).
const Set<String> _flatRoots = {'F', 'Bb', 'Eb', 'Ab', 'Db', 'Gb', 'Cb'};
bool rootUsesFlats(String root) => root.contains('b') || _flatRoots.contains(root);

/// Spell a pitch class with sharp or flat names.
String spell(int pc, bool useFlats) {
  final i = ((pc % 12) + 12) % 12;
  return (useFlats ? _flatNames : _sharpNames)[i];
}

/// Standard tuning, low → high (6th string E … 1st string e).
const List<String> kStandardTuning = ['E', 'A', 'D', 'G', 'B', 'E'];

enum ScaleCategory { common, pentatonicBlues, modes, exotic }

String scaleCategoryLabel(ScaleCategory c) => switch (c) {
      ScaleCategory.common => 'Common',
      ScaleCategory.pentatonicBlues => 'Pentatonic & Blues',
      ScaleCategory.modes => 'Modes',
      ScaleCategory.exotic => 'Exotic',
    };

class ScaleDef {
  final String id;
  final String name;
  final List<int> intervals;
  final ScaleCategory category;
  const ScaleDef(this.id, this.name, this.intervals, this.category);
}

/// 20+ scales as semitone offsets from the root, grouped for the picker.
const List<ScaleDef> kScales = [
  // Common
  ScaleDef('major', 'Major (Ionian)', [0, 2, 4, 5, 7, 9, 11], ScaleCategory.common),
  ScaleDef('natural-minor', 'Natural Minor (Aeolian)', [0, 2, 3, 5, 7, 8, 10], ScaleCategory.common),
  // Pentatonic & Blues
  ScaleDef('major-pentatonic', 'Major Pentatonic', [0, 2, 4, 7, 9], ScaleCategory.pentatonicBlues),
  ScaleDef('minor-pentatonic', 'Minor Pentatonic', [0, 3, 5, 7, 10], ScaleCategory.pentatonicBlues),
  ScaleDef('blues-minor', 'Blues (Minor)', [0, 3, 5, 6, 7, 10], ScaleCategory.pentatonicBlues),
  ScaleDef('blues-major', 'Blues (Major)', [0, 2, 3, 4, 7, 9], ScaleCategory.pentatonicBlues),
  // Modes
  ScaleDef('dorian', 'Dorian', [0, 2, 3, 5, 7, 9, 10], ScaleCategory.modes),
  ScaleDef('phrygian', 'Phrygian', [0, 1, 3, 5, 7, 8, 10], ScaleCategory.modes),
  ScaleDef('lydian', 'Lydian', [0, 2, 4, 6, 7, 9, 11], ScaleCategory.modes),
  ScaleDef('mixolydian', 'Mixolydian', [0, 2, 4, 5, 7, 9, 10], ScaleCategory.modes),
  ScaleDef('locrian', 'Locrian', [0, 1, 3, 5, 6, 8, 10], ScaleCategory.modes),
  // Exotic
  ScaleDef('harmonic-minor', 'Harmonic Minor', [0, 2, 3, 5, 7, 8, 11], ScaleCategory.exotic),
  ScaleDef('melodic-minor', 'Melodic Minor', [0, 2, 3, 5, 7, 9, 11], ScaleCategory.exotic),
  ScaleDef('phrygian-dominant', 'Phrygian Dominant', [0, 1, 4, 5, 7, 8, 10], ScaleCategory.exotic),
  ScaleDef('lydian-dominant', 'Lydian Dominant', [0, 2, 4, 6, 7, 9, 10], ScaleCategory.exotic),
  ScaleDef('dim-whole-half', 'Diminished (Whole-Half)', [0, 2, 3, 5, 6, 8, 9, 11], ScaleCategory.exotic),
  ScaleDef('dim-half-whole', 'Diminished (Half-Whole)', [0, 1, 3, 4, 6, 7, 9, 10], ScaleCategory.exotic),
  ScaleDef('whole-tone', 'Whole Tone', [0, 2, 4, 6, 8, 10], ScaleCategory.exotic),
  ScaleDef('augmented', 'Augmented', [0, 3, 4, 7, 8, 11], ScaleCategory.exotic),
  ScaleDef('altered', 'Altered (Super Locrian)', [0, 1, 3, 4, 6, 8, 10], ScaleCategory.exotic),
  ScaleDef('hungarian-minor', 'Hungarian Minor', [0, 2, 3, 6, 7, 8, 11], ScaleCategory.exotic),
];

/// Interval label for a semitone distance from the root (0-11).
const List<String> _intervalLabels = ['R', '♭2', '2', '♭3', '3', '4', '♭5', '5', '♭6', '6', '♭7', '7'];
String intervalLabel(int semitoneFromRoot) => _intervalLabels[((semitoneFromRoot % 12) + 12) % 12];

/// The spelled notes of a scale, in order from the root.
List<String> scaleNotes(String root, ScaleDef scale) {
  final rootPc = pitchClass(root);
  if (rootPc == null) return [];
  final useFlats = rootUsesFlats(root);
  return scale.intervals.map((i) => spell((rootPc + i) % 12, useFlats)).toList();
}

class FretNote {
  final int string; // 0 = low E (6th), 5 = high e (1st)
  final int fret; // 0 = open
  final int pc; // pitch class 0-11
  final String note; // spelled name
  final int degree; // semitones above the root, 0-11
  final String interval; // interval label (R, ♭3, 5, …)
  final bool isRoot;
  const FretNote({
    required this.string,
    required this.fret,
    required this.pc,
    required this.note,
    required this.degree,
    required this.interval,
    required this.isRoot,
  });
}

/// Every in-scale note on the board, fret 0..maxFret, for the given tuning.
/// Strings are indexed low → high (0 = low E).
List<FretNote> buildScaleFretboard(
  String root,
  ScaleDef scale, {
  int maxFret = 15,
  List<String> tuning = kStandardTuning,
}) {
  final rootPc = pitchClass(root);
  if (rootPc == null) return [];
  final useFlats = rootUsesFlats(root);
  final inScale = scale.intervals.map((i) => (rootPc + i) % 12).toSet();
  final out = <FretNote>[];
  for (var string = 0; string < tuning.length; string++) {
    final openPc = pitchClass(tuning[string]);
    if (openPc == null) continue;
    for (var fret = 0; fret <= maxFret; fret++) {
      final pc = (openPc + fret) % 12;
      if (!inScale.contains(pc)) continue;
      final degree = (((pc - rootPc) % 12) + 12) % 12;
      out.add(FretNote(
        string: string,
        fret: fret,
        pc: pc,
        note: spell(pc, useFlats),
        degree: degree,
        interval: intervalLabel(degree),
        isRoot: degree == 0,
      ));
    }
  }
  return out;
}
