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

// ── Pattern / position systems (Phase 2) ────────────────────────────────────
// Ported 1:1 from the web app's lib/fretboard-patterns.ts. Each pattern yields
// a list of "positions"; a position is the set of note cells (string:fret) it
// lights up. The board dims everything else. Standard tuning only.

enum PatternMode { full, caged, threeNps, diagonal }

String noteKey(int string, int fret) => '$string:$fret';

class Position {
  final String label;
  final Set<String> keys;
  const Position(this.label, this.keys);
}

// Open-string pitch classes (low E … high e) and their absolute semitones above
// the low E open string. The 15→19 gap encodes the G→B major third.
final List<int> _openPc = kStandardTuning.map((n) => pitchClass(n) ?? 0).toList();
const List<int> _openSemi = [0, 5, 10, 15, 19, 24];

Set<int> _scalePcs(String root, ScaleDef scale) {
  final rootPc = pitchClass(root) ?? 0;
  return scale.intervals.map((i) => (rootPc + i) % 12).toSet();
}

/// Root fret (0-11) on each string — the anchors for CAGED positions.
List<int> _rootAnchors(int rootPc) {
  final set = _openPc.map((pc) => (((rootPc - pc) % 12) + 12) % 12).toSet().toList();
  set.sort();
  return set;
}

/// Lit cells inside a per-string fret window.
Set<String> _windowKeys(
  Set<int> inScale,
  int maxFret,
  int Function(int s) lo,
  int Function(int s) hi,
) {
  final keys = <String>{};
  for (var s = 0; s < 6; s++) {
    final from = lo(s) < 0 ? 0 : lo(s);
    final to = hi(s) > maxFret ? maxFret : hi(s);
    for (var f = from; f <= to; f++) {
      if (inScale.contains((_openPc[s] + f) % 12)) keys.add(noteKey(s, f));
    }
  }
  return keys;
}

List<Position> _cagedPositions(int rootPc, Set<int> inScale, int maxFret) {
  final anchors = _rootAnchors(rootPc).take(5).toList();
  return [
    for (var i = 0; i < anchors.length; i++)
      Position('Position ${i + 1}',
          _windowKeys(inScale, maxFret, (_) => anchors[i] - 1, (_) => anchors[i] + 3)),
  ];
}

List<Position> _diagonalPositions(int rootPc, Set<int> inScale, int maxFret) {
  final anchors = _rootAnchors(rootPc);
  final bases = [
    anchors[0],
    anchors.length > 2 ? anchors[2] : anchors[1],
    anchors.length > 4 ? anchors[4] : anchors[anchors.length - 1],
  ];
  const shift = 2;
  const span = 3;
  return [
    for (var i = 0; i < bases.length; i++)
      Position('Diagonal ${i + 1}',
          _windowKeys(inScale, maxFret, (s) => bases[i] + s * shift, (s) => bases[i] + s * shift + span)),
  ];
}

/// Smallest semitone value ≥ v (above low E open) that is a scale tone.
int _nextScaleSemi(int v, Set<int> inScale, bool inclusive) {
  var w = inclusive ? v : v + 1;
  while (!inScale.contains((_openPc[0] + w) % 12)) {
    w++;
  }
  return w;
}

List<Position> _threeNpsPositions(int rootPc, Set<int> inScale, int maxFret) {
  // 3 notes per string is only standard for 7-note (diatonic) scales.
  if (inScale.length != 7) return [];
  final lowEStarts = <int>[];
  for (var f = 0; f < 12; f++) {
    if (inScale.contains((_openPc[0] + f) % 12)) lowEStarts.add(f);
  }
  final starts = lowEStarts.take(7).toList();
  final out = <Position>[];
  for (var k = 0; k < starts.length; k++) {
    final keys = <String>{};
    var current = starts[k];
    for (var s = 0; s < 6; s++) {
      var v = _nextScaleSemi(current, inScale, true);
      for (var n = 0; n < 3; n++) {
        final fret = v - _openSemi[s];
        if (fret >= 0 && fret <= maxFret) keys.add(noteKey(s, fret));
        v = _nextScaleSemi(v, inScale, false);
      }
      current = v; // next string picks up at the next scale tone
    }
    out.add(Position('Position ${k + 1}', keys));
  }
  return out;
}

/// Positions for the chosen pattern. Empty list = no position filtering.
List<Position> getPositions(PatternMode mode, String root, ScaleDef scale, int maxFret) {
  if (mode == PatternMode.full) return const [];
  final rootPc = pitchClass(root) ?? 0;
  final inScale = _scalePcs(root, scale);
  return switch (mode) {
    PatternMode.caged => _cagedPositions(rootPc, inScale, maxFret),
    PatternMode.diagonal => _diagonalPositions(rootPc, inScale, maxFret),
    PatternMode.threeNps => _threeNpsPositions(rootPc, inScale, maxFret),
    PatternMode.full => const [],
  };
}

// ── Scale comparison (Phase 3) ──────────────────────────────────────────────
// Ported from web lib/fretboard.ts buildComparison/sharedToneCount.

class CompareNote {
  final int string;
  final int fret;
  final int pc;
  final String note;
  final int degree;
  final String interval;
  final bool isRoot;
  final bool inA;
  final bool inB;
  const CompareNote({
    required this.string,
    required this.fret,
    required this.pc,
    required this.note,
    required this.degree,
    required this.interval,
    required this.isRoot,
    required this.inA,
    required this.inB,
  });
}

/// Every note in scale A and/or scale B (same root), tagged with which scale(s)
/// it belongs to — for the side-by-side comparison overlay.
List<CompareNote> buildComparison(
  String root,
  ScaleDef scaleA,
  ScaleDef scaleB, {
  int maxFret = 15,
  List<String> tuning = kStandardTuning,
}) {
  final rootPc = pitchClass(root);
  if (rootPc == null) return [];
  final useFlats = rootUsesFlats(root);
  final aSet = scaleA.intervals.map((i) => (rootPc + i) % 12).toSet();
  final bSet = scaleB.intervals.map((i) => (rootPc + i) % 12).toSet();
  final out = <CompareNote>[];
  for (var string = 0; string < tuning.length; string++) {
    final openPc = pitchClass(tuning[string]);
    if (openPc == null) continue;
    for (var fret = 0; fret <= maxFret; fret++) {
      final pc = (openPc + fret) % 12;
      final inA = aSet.contains(pc);
      final inB = bSet.contains(pc);
      if (!inA && !inB) continue;
      final degree = (((pc - rootPc) % 12) + 12) % 12;
      out.add(CompareNote(
        string: string,
        fret: fret,
        pc: pc,
        note: spell(pc, useFlats),
        degree: degree,
        interval: intervalLabel(degree),
        isRoot: degree == 0,
        inA: inA,
        inB: inB,
      ));
    }
  }
  return out;
}

/// Count of shared pitch classes between two scales at the same root.
int sharedToneCount(ScaleDef scaleA, ScaleDef scaleB) {
  final b = scaleB.intervals.map((i) => i % 12).toSet();
  return scaleA.intervals.map((i) => i % 12).toSet().where(b.contains).length;
}

// ── Diatonic chords (Phase 4) ───────────────────────────────────────────────
// Ported from web lib/fretboard-chords.ts. Stacks thirds *within* the scale so
// every 7-note scale yields its correct triads. Empty for non-7-note scales.
// Known limitation (same as web): enharmonic spelling follows the root's
// major-key preference (rootUsesFlats), so e.g. C harmonic minor shows D#aug,
// not Eb+ — pitch right, spelling sharp.

class DiatonicChord {
  final int degree; // 1..7
  final String roman; // e.g. "ii", "♭VII", "vii°"
  final String name; // triad name, e.g. "Am"
  final String seventh; // seventh-chord name, e.g. "Am7"
  final String quality; // maj | min | dim | aug
  final String rootNote;
  final List<String> notes; // triad note names
  final List<int> pcs; // triad pitch classes
  const DiatonicChord({
    required this.degree,
    required this.roman,
    required this.name,
    required this.seventh,
    required this.quality,
    required this.rootNote,
    required this.notes,
    required this.pcs,
  });
}

const List<int> _majorRef = [0, 2, 4, 5, 7, 9, 11];
const List<String> _romanNumerals = ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII'];

/// Scale tone `step` degrees above degree `i`, in absolute semitones.
int _stackTone(List<int> deg, int i, int step) =>
    deg[(i + step) % 7] + ((i + step) ~/ 7) * 12;

String _seventhSuffix(String quality, int gap) {
  if (quality == 'maj') return gap == 11 ? 'maj7' : '7';
  if (quality == 'min') return gap == 11 ? 'm(maj7)' : 'm7';
  if (quality == 'dim') return gap == 9 ? '°7' : 'm7♭5';
  return gap == 11 ? 'maj7♯5' : '7♯5'; // aug
}

/// Diatonic triads (+7th names) for a 7-note scale. Empty for other scales.
List<DiatonicChord> buildDiatonicChords(String root, ScaleDef scale) {
  if (scale.intervals.length != 7) return [];
  final rootPc = pitchClass(root);
  if (rootPc == null) return [];
  final useFlats = rootUsesFlats(root);
  final deg = scale.intervals;
  final chords = <DiatonicChord>[];

  for (var i = 0; i < 7; i++) {
    final r = deg[i];
    final third = _stackTone(deg, i, 2);
    final fifth = _stackTone(deg, i, 4);
    final seventh = _stackTone(deg, i, 6);
    final t = (third - r) % 12; // third interval
    final f = (fifth - r) % 12; // fifth interval
    final sGap = (seventh - r) % 12;

    String quality;
    String suffix;
    var mark = '';
    if (t == 4 && f == 7) {
      quality = 'maj';
      suffix = '';
    } else if (t == 3 && f == 7) {
      quality = 'min';
      suffix = 'm';
    } else if (t == 3 && f == 6) {
      quality = 'dim';
      suffix = 'dim';
      mark = '°';
    } else if (t == 4 && f == 8) {
      quality = 'aug';
      suffix = 'aug';
      mark = '+';
    } else {
      // Non-tertian degree (rare, exotic scales) — fall back by the third.
      quality = t <= 3 ? 'min' : 'maj';
      suffix = t <= 3 ? 'm' : '';
    }

    final acc = r < _majorRef[i] ? '♭' : (r > _majorRef[i] ? '♯' : '');
    var roman = acc + _romanNumerals[i];
    if (quality == 'min' || quality == 'dim') roman = roman.toLowerCase();
    roman += mark;

    final pcs = [r, third, fifth].map((x) => (rootPc + x) % 12).toList();
    final rootNote = spell((rootPc + r) % 12, useFlats);
    chords.add(DiatonicChord(
      degree: i + 1,
      roman: roman,
      name: rootNote + suffix,
      seventh: rootNote + _seventhSuffix(quality, sGap),
      quality: quality,
      rootNote: rootNote,
      notes: pcs.map((pc) => spell(pc, useFlats)).toList(),
      pcs: pcs,
    ));
  }
  return chords;
}
