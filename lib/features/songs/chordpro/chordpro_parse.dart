// Light parser for ChordPro source blocks pulled from third-party
// services (CCLI SongSelect, OnSong, etc). Mirrors the web app's
// lib/chordpro-parse.ts so the bulk import feels the same.

class ParsedChordPro {
  ParsedChordPro({
    required this.body,
    this.title,
    this.artist,
    this.originalKey,
    this.bpm,
  });
  final String body;
  final String? title;
  final String? artist;
  final String? originalKey;
  final int? bpm;
}

/// Upper bound for a single song's chordpro_body. Real charts are 1-5 KB.
const maxChordProBytes = 50 * 1024;

String? _readDirective(String body, String name) {
  final re = RegExp('\\{$name\\s*:\\s*([^}]+)\\}', caseSensitive: false);
  return re.firstMatch(body)?.group(1)?.trim();
}

ParsedChordPro parseSingleChordPro(String raw) {
  final body = raw.trim();
  final title = _readDirective(body, 'title') ?? _readDirective(body, 't');
  final artist =
      _readDirective(body, 'artist') ?? _readDirective(body, 'subtitle');
  final key = _readDirective(body, 'key');
  final bpmRaw = _readDirective(body, 'tempo');
  final bpm = bpmRaw == null
      ? null
      : int.tryParse(RegExp(r'\d+').firstMatch(bpmRaw)?.group(0) ?? '');
  return ParsedChordPro(
    body: body,
    title: title,
    artist: artist,
    originalKey: key,
    bpm: bpm,
  );
}

/// Split a paste containing multiple ChordPro blocks. Songs are separated by
///   1) a line containing only `---` (three or more dashes) — explicit
///   2) OR a fresh `{title: ...}` directive at the start of a line
List<String> splitChordProBlocks(String raw) {
  final text = raw.replaceAll('\r\n', '\n').trim();
  if (text.isEmpty) return const [];

  final explicit = text
      .split(RegExp(r'^---+$', multiLine: true))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  if (explicit.length > 1) return explicit;

  final parts = <String>[];
  final re = RegExp(r'^\{title\s*:', multiLine: true, caseSensitive: false);
  var lastIndex = 0;
  for (final m in re.allMatches(text)) {
    if (m.start > lastIndex) {
      final chunk = text.substring(lastIndex, m.start).trim();
      if (chunk.isNotEmpty) parts.add(chunk);
    }
    lastIndex = m.start;
  }
  final tail = text.substring(lastIndex).trim();
  if (tail.isNotEmpty) parts.add(tail);

  return parts.isEmpty ? [text] : parts;
}
