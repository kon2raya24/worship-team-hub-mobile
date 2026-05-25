import 'package:flutter_test/flutter_test.dart';
import 'package:worship_team_hub/features/songs/chordpro/chordpro.dart';

void main() {
  group('ChordPro.parse', () {
    test('reads {title} and {key} directives', () {
      final song = ChordPro.parse('{title: Amazing Grace}\n{key: G}\n');
      expect(song.title, 'Amazing Grace');
      expect(song.key, 'G');
    });

    test('splits sections on {comment}', () {
      final song = ChordPro.parse(
        '{comment: Verse 1}\n[G]Line one\n{comment: Chorus}\n[C]Line two\n',
      );
      expect(song.sections.length, 2);
      expect(song.sections[0].label, 'Verse 1');
      expect(song.sections[1].label, 'Chorus');
    });

    test('pairs inline chord with following lyric text', () {
      final song = ChordPro.parse('A[G]mazing [C]grace\n');
      final segs = song.sections.first.lines.first.segments;
      // Leading "A" before first chord, then [G]mazing space, then [C]grace
      expect(segs.length, 3);
      expect(segs[0].chord, isNull);
      expect(segs[0].text, 'A');
      expect(segs[1].chord, 'G');
      expect(segs[1].text, 'mazing ');
      expect(segs[2].chord, 'C');
      expect(segs[2].text, 'grace');
    });
  });

  group('ChordPro.transposeChord', () {
    test('shifts simple major chords up', () {
      expect(ChordPro.transposeChord('C', 2, false), 'D');
      expect(ChordPro.transposeChord('G', 2, false), 'A');
      expect(ChordPro.transposeChord('A', 3, false), 'C');
    });

    test('shifts down through zero', () {
      expect(ChordPro.transposeChord('C', -1, false), 'B');
      expect(ChordPro.transposeChord('D', -2, false), 'C');
    });

    test('preserves minor / 7 / sus suffixes', () {
      expect(ChordPro.transposeChord('Am', 2, false), 'Bm');
      expect(ChordPro.transposeChord('Gmaj7', 2, false), 'Amaj7');
      expect(ChordPro.transposeChord('Dsus4', 2, false), 'Esus4');
    });

    test('handles slash chords', () {
      expect(ChordPro.transposeChord('G/B', 2, false), 'A/C#');
      expect(ChordPro.transposeChord('C/E', 5, false), 'F/A');
    });

    test('prefers flats when requested', () {
      expect(ChordPro.transposeChord('C', 1, true), 'Db');
      expect(ChordPro.transposeChord('F', -1, true), 'E');
      expect(ChordPro.transposeChord('Bb', 2, true), 'C');
    });

    test('leaves unrecognized tokens alone', () {
      expect(ChordPro.transposeChord('N.C.', 5, false), 'N.C.');
      expect(ChordPro.transposeChord('', 5, false), '');
    });
  });

  group('ChordPro.semitonesBetween', () {
    test('common up shifts', () {
      expect(ChordPro.semitonesBetween('G', 'A'), 2);
      expect(ChordPro.semitonesBetween('C', 'E'), 4);
      expect(ChordPro.semitonesBetween('G', 'C'), 5);
    });
    test('common down shifts', () {
      expect(ChordPro.semitonesBetween('A', 'G'), -2);
      expect(ChordPro.semitonesBetween('E', 'D'), -2);
    });
    test('wraps to closest direction', () {
      // G → F# could be -1 or +11; should pick -1.
      expect(ChordPro.semitonesBetween('G', 'F#'), -1);
      // G → A# is +3, not -9.
      expect(ChordPro.semitonesBetween('G', 'A#'), 3);
    });
    test('returns 0 for nulls/empties/garbage', () {
      expect(ChordPro.semitonesBetween(null, 'A'), 0);
      expect(ChordPro.semitonesBetween('G', null), 0);
      expect(ChordPro.semitonesBetween('', 'A'), 0);
      expect(ChordPro.semitonesBetween('G', 'N.C.'), 0);
    });
  });

  group('ChordPro.transpose (whole song)', () {
    test('transposes every chord and the key directive', () {
      final song = ChordPro.parse('{key: G}\n[G]hi [Am]there [D]friend\n');
      final transposed = ChordPro.transpose(song, 2);
      expect(transposed.key, 'A');
      final chords = transposed.sections.first.lines.first.segments
          .map((s) => s.chord)
          .whereType<String>()
          .toList();
      expect(chords, ['A', 'Bm', 'E']);
    });

    test('roundtrips identity when semitones = 0', () {
      final input = '{key: D}\n[D]Hello [G]world\n';
      final song = ChordPro.parse(input);
      final back = ChordPro.transpose(song, 0);
      expect(back.key, 'D');
      expect(
        back.sections.first.lines.first.segments.map((s) => s.chord).toList(),
        ['D', 'G'],
      );
    });
  });
}
