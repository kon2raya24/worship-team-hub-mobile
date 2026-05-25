// Convert "chord-above-lyrics" text (Ultimate Guitar / printed chord
// sheets) into inline ChordPro format ([C]lyric). Port of the web app's
// lib/chord-line-parse.ts — same heuristic + idempotent on input that's
// already ChordPro.

final _chordToken = RegExp(
  r'^[A-G][b#♭♯]?(?:maj|min|m|M|sus|aug|dim|add|°|ø|Δ)*\d*'
  r'(?:sus[24])?(?:add\d+)?(?:[b#]\d+)?(?:/[A-G][b#♭♯]?\d*)?$',
);

final _sectionRe = RegExp(r'^\[([^\]]+)\]\s*(.*)$');

bool _isChordLine(String line) {
  final t = line.trim();
  if (t.isEmpty) return false;
  if (t.startsWith('[') || t.startsWith('{')) return false;
  // Obvious lyric punctuation rejects.
  if (RegExp(r'[,.!?;:"]').hasMatch(t)) return false;
  final tokens = t.split(RegExp(r'\s+'));
  if (tokens.isEmpty) return false;
  return tokens.every((tok) => _chordToken.hasMatch(tok));
}

String _chordOnlyLine(String chordLine) {
  final chords = RegExp(r'\S+')
      .allMatches(chordLine)
      .map((m) => '[${m.group(0)!}]')
      .toList();
  return chords.join(' ');
}

String _mergeChordsIntoLyric(String chordLine, String lyricLine) {
  final chords = RegExp(r'\S+')
      .allMatches(chordLine)
      .map((m) => (col: m.start, chord: m.group(0)!))
      .toList();
  final out = StringBuffer();
  var cursor = 0;
  for (final c in chords) {
    while (cursor < c.col && cursor < lyricLine.length) {
      out.write(lyricLine[cursor]);
      cursor++;
    }
    while (cursor < c.col) {
      out.write(' ');
      cursor++;
    }
    out.write('[${c.chord}]');
  }
  out.write(lyricLine.substring(cursor.clamp(0, lyricLine.length)));
  return out.toString();
}

String convertChordOverLyrics(String input) {
  final lines = input.replaceAll('\r\n', '\n').split('\n');
  final result = <String>[];
  var i = 0;
  while (i < lines.length) {
    final line = lines[i];
    final trimmed = line.trim();

    if (trimmed.isEmpty) {
      result.add('');
      i++;
      continue;
    }

    final section = _sectionRe.firstMatch(trimmed);
    if (section != null) {
      final name = (section.group(1) ?? '').trim();
      result.add('{comment: $name}');
      final rest = section.group(2);
      if (rest != null && rest.trim().isNotEmpty) result.add(rest);
      i++;
      continue;
    }

    if (_isChordLine(line)) {
      var j = i + 1;
      while (j < lines.length && lines[j].trim().isEmpty) {
        j++;
      }
      final next = j < lines.length ? lines[j] : null;
      final nextTrim = next?.trim() ?? '';
      final nextIsLyric = next != null &&
          nextTrim.isNotEmpty &&
          !nextTrim.startsWith('[') &&
          !nextTrim.startsWith('{') &&
          !_isChordLine(next);

      if (nextIsLyric) {
        result.add(_mergeChordsIntoLyric(line, next));
        i = j + 1;
      } else {
        result.add(_chordOnlyLine(line));
        i++;
      }
      continue;
    }

    result.add(line);
    i++;
  }

  // Collapse 3+ consecutive blank lines to 2.
  return result.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n');
}

bool looksLikeChordOverLyrics(String input) {
  final lines = input.replaceAll('\r\n', '\n').split('\n');
  var chordLines = 0;
  for (final line in lines) {
    if (_isChordLine(line)) chordLines++;
    if (chordLines >= 2) return true;
  }
  return false;
}
