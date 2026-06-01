import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../chordpro/chordpro.dart';

/// Renders a ParsedSong with chords sitting directly above the syllable
/// they apply to, like a printed chord chart. Monospaced so columns align.
class ChordViewer extends StatelessWidget {
  const ChordViewer({super.key, required this.song, this.fontSize = 14});

  final ParsedSong song;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final blocks = <Widget>[];
    for (var i = 0; i < song.sections.length; i++) {
      final sec = song.sections[i];
      if (sec.label != null && sec.label!.isNotEmpty) {
        blocks.add(_SectionLabel(label: sec.label!));
      }
      for (final line in sec.lines) {
        blocks.add(_LineWidget(line: line, fontSize: fontSize));
      }
      if (i < song.sections.length - 1) {
        blocks.add(const SizedBox(height: 12));
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Text(
        label.toUpperCase(),
        style: Sanctuary.mono(
          fontSize: 11,
          color: Sanctuary.auroraCyan,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _LineWidget extends StatelessWidget {
  const _LineWidget({required this.line, required this.fontSize});

  final ChordLine line;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    if (line.isBlank) return SizedBox(height: fontSize * 0.6);

    final cs = Theme.of(context).colorScheme;
    final chordStyle = Sanctuary.mono(
      fontSize: fontSize,
      color: Sanctuary.auroraCyan,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
    );
    final lyricStyle = Sanctuary.mono(
      fontSize: fontSize,
      color: cs.onSurface,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
    );

    final children = <Widget>[];
    for (final seg in line.segments) {
      children.add(
        _Segment(
          chord: seg.chord,
          text: seg.text,
          chordStyle: chordStyle,
          lyricStyle: lyricStyle,
        ),
      );
    }
    // Wrap (not Row) so long lines spill onto the next visual row instead
    // of overflowing the screen. Each segment keeps its chord-over-syllable
    // alignment internally, so the wrap point sits cleanly between segments.
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.start,
        children: children,
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.chord,
    required this.text,
    required this.chordStyle,
    required this.lyricStyle,
  });

  final String? chord;
  final String text;
  final TextStyle chordStyle;
  final TextStyle lyricStyle;

  @override
  Widget build(BuildContext context) {
    // Pad lyric with a trailing space so consecutive chords don't collide.
    final lyricText = text.isEmpty ? ' ' : text;
    final chordText = chord ?? '';
    // Pad chord with one trailing space so the next chord can't touch.
    final chordDisplay = chordText.isEmpty ? '' : '$chordText ';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: chordStyle.fontSize! * 1.2,
          child: Text(chordDisplay, style: chordStyle),
        ),
        Text(lyricText, style: lyricStyle),
      ],
    );
  }
}
