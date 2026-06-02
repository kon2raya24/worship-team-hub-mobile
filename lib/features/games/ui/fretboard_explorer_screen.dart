import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../fretboard_data.dart';

enum LabelMode { notes, intervals, hide }

/// Fretboard Explorer — Phase 1 (core). Pick a key + scale, see every in-scale
/// note across the whole neck, and toggle Notes / Intervals / Hide labels.
/// The board is drawn with a [CustomPainter]; later phases (patterns,
/// comparison, chords, editing/export) build on this.
class FretboardExplorerScreen extends StatefulWidget {
  const FretboardExplorerScreen({super.key});

  @override
  State<FretboardExplorerScreen> createState() => _FretboardExplorerScreenState();
}

class _FretboardExplorerScreenState extends State<FretboardExplorerScreen> {
  String _root = 'G';
  String _scaleId = 'major';
  LabelMode _label = LabelMode.notes;
  PatternMode _pattern = PatternMode.full;
  int _posIndex = 0; // which position is in focus (CAGED/3NPS/Diagonal)
  bool _compare = false;
  String _scaleBId = 'natural-minor';

  ScaleDef get _scale =>
      kScales.firstWhere((s) => s.id == _scaleId, orElse: () => kScales.first);
  ScaleDef get _scaleB =>
      kScales.firstWhere((s) => s.id == _scaleBId, orElse: () => kScales[1]);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scale = _scale;
    final scaleB = _scaleB;
    final notes = buildScaleFretboard(_root, scale);
    final names = scaleNotes(_root, scale);
    final compareNotes = _compare ? buildComparison(_root, scale, scaleB) : null;
    final shared = sharedToneCount(scale, scaleB);
    final aOnly = scale.intervals.length - shared;
    final bOnly = scaleB.intervals.length - shared;
    // Pattern filtering only applies to the single-scale view.
    final positions = _compare
        ? const <Position>[]
        : getPositions(_pattern, _root, scale, _FretboardPainter.maxFret);
    final hasPositions = positions.isNotEmpty;
    final idx = hasPositions ? _posIndex % positions.length : 0;
    final activeKeys = hasPositions ? positions[idx].keys : null;
    // 3NPS is only defined for 7-note scales — fall back gracefully otherwise.
    final npsUnavailable =
        !_compare && _pattern == PatternMode.threeNps && !hasPositions;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 20),
          onPressed: () => context.canPop() ? context.pop() : context.go('/games'),
        ),
        title: const Text('Fretboard'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('KEY', style: Sanctuary.mono(fontSize: 10, color: cs.onSurfaceVariant)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final r in kRoots) _keyChip(cs, isDark, r)],
          ),
          const SizedBox(height: 16),
          Text(_compare ? 'SCALE A' : 'SCALE',
              style: Sanctuary.mono(fontSize: 10, color: cs.onSurfaceVariant)),
          const SizedBox(height: 8),
          _scaleSelect(cs, isDark, _scaleId, (v) {
            setState(() {
              _scaleId = v;
              _posIndex = 0;
            });
          }),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text('Compare two scales',
                    style: TextStyle(color: cs.onSurface, fontSize: 13)),
              ),
              Switch(
                value: _compare,
                onChanged: (v) => setState(() => _compare = v),
              ),
            ],
          ),
          if (_compare) ...[
            const SizedBox(height: 4),
            Text('SCALE B', style: Sanctuary.mono(fontSize: 10, color: cs.onSurfaceVariant)),
            const SizedBox(height: 8),
            _scaleSelect(cs, isDark, _scaleBId, (v) {
              setState(() => _scaleBId = v);
            }),
          ],
          const SizedBox(height: 16),
          Text('LABELS', style: Sanctuary.mono(fontSize: 10, color: cs.onSurfaceVariant)),
          const SizedBox(height: 8),
          Row(
            children: [
              _labelChip(cs, isDark, 'Notes', LabelMode.notes),
              const SizedBox(width: 6),
              _labelChip(cs, isDark, 'Intervals', LabelMode.intervals),
              const SizedBox(width: 6),
              _labelChip(cs, isDark, 'Hide', LabelMode.hide),
            ],
          ),
          const SizedBox(height: 16),
          if (!_compare) ...[
            Text('PATTERN', style: Sanctuary.mono(fontSize: 10, color: cs.onSurfaceVariant)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _patternChip(cs, isDark, 'Full', PatternMode.full),
                _patternChip(cs, isDark, 'CAGED', PatternMode.caged),
                _patternChip(cs, isDark, '3 NPS', PatternMode.threeNps),
                _patternChip(cs, isDark, 'Diagonal', PatternMode.diagonal),
              ],
            ),
            if (hasPositions) ...[
              const SizedBox(height: 10),
              _positionStepper(cs, isDark, positions[idx].label, idx, positions.length),
            ],
            if (npsUnavailable) ...[
              const SizedBox(height: 10),
              Text(
                '3 notes-per-string positions are defined for 7-note scales — '
                'pick a heptatonic scale (e.g. a major, minor, or modal scale).',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12, height: 1.4),
              ),
            ],
            const SizedBox(height: 16),
          ],

          // The neck — scroll horizontally to see all 15 frets.
          GlassCard(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: CustomPaint(
                    size: const Size(_FretboardPainter.totalW, _FretboardPainter.totalH),
                    painter: _FretboardPainter(
                      notes: notes,
                      compareNotes: compareNotes,
                      label: _label,
                      activeKeys: activeKeys,
                      signature:
                          '$_root|$_scaleId|${_label.index}|${_pattern.index}|$idx|$hasPositions|'
                          '$_compare|$_scaleBId|$isDark',
                      boardFill: cs.onSurface.withValues(alpha: 0.04),
                      line: cs.outlineVariant,
                      nut: cs.onSurfaceVariant.withValues(alpha: 0.6),
                      inlay: cs.onSurfaceVariant.withValues(alpha: 0.22),
                      fretNum: cs.onSurfaceVariant,
                      rootFill: cs.primary,
                      rootText: cs.onPrimary,
                      noteFill: cs.secondary,
                      noteText: cs.onSecondary,
                      dotStroke: cs.surface,
                      amber: Sanctuary.auroraAmber,
                      ring: cs.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Standard tuning — low E on top · scroll to see all 15 frets',
                  style: Sanctuary.mono(fontSize: 10, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (_compare) ...[
            Text('$_root · ${scale.name}  vs  ${scaleB.name}',
                style: Sanctuary.display(fontSize: 15, color: cs.onSurface)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _legendChip(cs, cs.primary, 'Both', shared),
                _legendChip(cs, cs.secondary, 'Only A', aOnly),
                _legendChip(cs, Sanctuary.auroraAmber, 'Only B', bOnly, hollow: true),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Violet = shared tones · cyan = only in A · amber outline = only in B. '
              'A ring marks the root. Great for spotting how two scales overlap.',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12, height: 1.4),
            ),
          ] else ...[
            Text('$_root ${scale.name}',
                style: Sanctuary.display(fontSize: 16, color: cs.onSurface)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final n in names)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.12),
                      border: Border.all(color: cs.primary.withValues(alpha: 0.35)),
                      borderRadius: BorderRadius.circular(Sanctuary.radiusMd),
                    ),
                    child: Text(n,
                        style: Sanctuary.mono(
                            fontSize: 12, color: cs.primary, letterSpacing: 0)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Violet = the root. Cyan = the other scale tones. Pick a key and scale, '
              'then practise the shapes across the neck.',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  Widget _legendChip(ColorScheme cs, Color color, String label, int count,
      {bool hollow = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.4),
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(Sanctuary.radiusMd),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: hollow ? Colors.transparent : color,
              border: Border.all(color: color, width: 2),
            ),
          ),
          const SizedBox(width: 6),
          Text('$label · $count',
              style: Sanctuary.mono(fontSize: 11, color: cs.onSurface, letterSpacing: 0)),
        ],
      ),
    );
  }

  Widget _keyChip(ColorScheme cs, bool isDark, String r) {
    final selected = r == _root;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(Sanctuary.radiusMd),
        onTap: () => setState(() {
          _root = r;
          _posIndex = 0;
        }),
        child: Container(
          constraints: const BoxConstraints(minWidth: 40),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? cs.primary.withValues(alpha: 0.15)
                : (isDark ? Sanctuary.glass1 : Sanctuary.lightGlass1),
            border: Border.all(
                color: selected
                    ? cs.primary.withValues(alpha: 0.5)
                    : cs.outlineVariant),
            borderRadius: BorderRadius.circular(Sanctuary.radiusMd),
          ),
          child: Text(
            r,
            textAlign: TextAlign.center,
            style: Sanctuary.mono(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? cs.primary : cs.onSurface,
              letterSpacing: 0,
            ),
          ),
        ),
      ),
    );
  }

  Widget _labelChip(ColorScheme cs, bool isDark, String label, LabelMode mode) {
    final selected = _label == mode;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(Sanctuary.radiusMd),
          onTap: () => setState(() => _label = mode),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? cs.primary.withValues(alpha: 0.15)
                  : (isDark ? Sanctuary.glass1 : Sanctuary.lightGlass1),
              border: Border.all(
                  color: selected
                      ? cs.primary.withValues(alpha: 0.5)
                      : cs.outlineVariant),
              borderRadius: BorderRadius.circular(Sanctuary.radiusMd),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: selected ? cs.primary : cs.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _patternChip(ColorScheme cs, bool isDark, String label, PatternMode mode) {
    final selected = _pattern == mode;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(Sanctuary.radiusMd),
        onTap: () => setState(() {
          _pattern = mode;
          _posIndex = 0;
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? cs.primary.withValues(alpha: 0.15)
                : (isDark ? Sanctuary.glass1 : Sanctuary.lightGlass1),
            border: Border.all(
                color: selected
                    ? cs.primary.withValues(alpha: 0.5)
                    : cs.outlineVariant),
            borderRadius: BorderRadius.circular(Sanctuary.radiusMd),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: selected ? cs.primary : cs.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _positionStepper(
      ColorScheme cs, bool isDark, String label, int idx, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Sanctuary.glass1 : Sanctuary.lightGlass1,
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(Sanctuary.radiusMd),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.chevron_left, size: 20),
            onPressed: () =>
                setState(() => _posIndex = (idx - 1 + count) % count),
          ),
          Text('$label  ·  ${idx + 1}/$count',
              style: Sanctuary.mono(
                  fontSize: 11, color: cs.onSurface, letterSpacing: 0)),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.chevron_right, size: 20),
            onPressed: () => setState(() => _posIndex = (idx + 1) % count),
          ),
        ],
      ),
    );
  }

  Widget _scaleSelect(
      ColorScheme cs, bool isDark, String value, ValueChanged<String> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? Sanctuary.glass1 : Sanctuary.lightGlass1,
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(Sanctuary.radiusMd),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          borderRadius: BorderRadius.circular(Sanctuary.radiusMd),
          dropdownColor: isDark ? Sanctuary.ink2 : Sanctuary.lightInk1,
          icon: Icon(Icons.expand_more, color: cs.onSurfaceVariant),
          style: TextStyle(color: cs.onSurface, fontSize: 14),
          items: [
            for (final s in kScales)
              DropdownMenuItem(
                value: s.id,
                child: Text(
                  s.name,
                  style: TextStyle(color: cs.onSurface, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

/// Draws the neck: board fill, inlays, strings, nut, fret wires, fret numbers,
/// and a coloured dot (root = primary, other tones = secondary) at every
/// in-scale position, with the note name or interval inside it.
class _FretboardPainter extends CustomPainter {
  _FretboardPainter({
    required this.notes,
    required this.compareNotes,
    required this.label,
    required this.activeKeys,
    required this.signature,
    required this.boardFill,
    required this.line,
    required this.nut,
    required this.inlay,
    required this.fretNum,
    required this.rootFill,
    required this.rootText,
    required this.noteFill,
    required this.noteText,
    required this.dotStroke,
    required this.amber,
    required this.ring,
  });

  final List<FretNote> notes;
  final List<CompareNote>? compareNotes; // non-null = comparison overlay
  final LabelMode label;
  final Set<String>? activeKeys; // null = show the whole board (no dimming)
  final String signature;
  final Color boardFill;
  final Color line;
  final Color nut;
  final Color inlay;
  final Color fretNum;
  final Color rootFill;
  final Color rootText;
  final Color noteFill;
  final Color noteText;
  final Color dotStroke;
  final Color amber; // B-only outline + label in compare mode
  final Color ring; // root ring in compare mode

  // Geometry (px) — proportions mirror the web SVG, tuned for mobile.
  static const double stringGap = 30;
  static const double fretW = 46;
  static const double padT = 20;
  static const double padL = 52; // open-note column, left of the nut
  static const double padR = 16;
  static const double padB = 34; // fret numbers
  static const double dotR = 11;
  static const int nStrings = 6;
  static const int maxFret = 15;
  static const List<int> inlayFrets = [3, 5, 7, 9, 15];
  static const int doubleInlay = 12;
  static const double boardH = stringGap * (nStrings - 1);
  static const double totalW = padL + fretW * maxFret + padR;
  static const double totalH = padT + boardH + padB;

  double _stringY(int s) => padT + s * stringGap;
  // Fretted notes sit in the middle of a fret space; the open note sits in the
  // column left of the nut.
  double _noteX(int f) => f == 0 ? padL * 0.5 : padL + fretW * (f - 0.5);
  double _wireX(int f) => padL + fretW * f;

  @override
  void paint(Canvas canvas, Size size) {
    final neckLeft = padL;
    final neckRight = padL + fretW * maxFret;

    // Neck fill.
    final fill = Paint()..color = boardFill;
    canvas.drawRRect(
      RRect.fromLTRBR(neckLeft, padT - 8, neckRight, padT + boardH + 8,
          const Radius.circular(6)),
      fill,
    );

    // Inlays (faint).
    final inlayPaint = Paint()..color = inlay;
    final midY = padT + boardH / 2;
    for (final f in inlayFrets) {
      canvas.drawCircle(Offset(_noteX(f), midY), 5, inlayPaint);
    }
    canvas.drawCircle(Offset(_noteX(doubleInlay), padT + boardH * 0.3), 5, inlayPaint);
    canvas.drawCircle(Offset(_noteX(doubleInlay), padT + boardH * 0.7), 5, inlayPaint);

    // Strings (low E on top → high e on bottom). Lower strings drawn thicker.
    for (var s = 0; s < nStrings; s++) {
      final p = Paint()
        ..color = line
        ..strokeWidth = 0.8 + (nStrings - 1 - s) * 0.22;
      canvas.drawLine(Offset(10, _stringY(s)), Offset(neckRight, _stringY(s)), p);
    }

    // Nut (thick) + fret wires.
    canvas.drawLine(
      Offset(neckLeft, padT - 2),
      Offset(neckLeft, padT + boardH + 2),
      Paint()
        ..color = nut
        ..strokeWidth = 4,
    );
    final wirePaint = Paint()
      ..color = line
      ..strokeWidth = 1.2;
    for (var f = 1; f <= maxFret; f++) {
      canvas.drawLine(Offset(_wireX(f), padT), Offset(_wireX(f), padT + boardH), wirePaint);
    }

    // Fret numbers under the board.
    for (var f = 1; f <= maxFret; f++) {
      _text(canvas, '$f', Offset(_noteX(f), padT + boardH + 16),
          Sanctuary.mono(fontSize: 10, color: fretNum, letterSpacing: 0));
    }

    if (compareNotes != null) {
      _paintCompare(canvas);
      return;
    }

    // Note dots. Out-of-position notes (when a pattern is active) are dimmed,
    // not hidden, so the player still sees the whole scale behind the shape.
    for (final n in notes) {
      final c = Offset(_noteX(n.fret), _stringY(n.string));
      final dim = activeKeys != null && !activeKeys!.contains('${n.string}:${n.fret}');
      final f = dim ? 0.14 : 1.0;
      final fillColor = n.isRoot ? rootFill : noteFill;
      canvas.drawCircle(c, dotR, Paint()..color = fillColor.withValues(alpha: fillColor.a * f));
      // Separating ring so adjacent dots stay distinct.
      canvas.drawCircle(
        c,
        dotR,
        Paint()
          ..color = dotStroke.withValues(alpha: dotStroke.a * f)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      if (label != LabelMode.hide) {
        final text = label == LabelMode.intervals ? n.interval : n.note;
        final tcol = n.isRoot ? rootText : noteText;
        _text(
          canvas,
          text,
          c,
          Sanctuary.mono(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: tcol.withValues(alpha: tcol.a * f),
            letterSpacing: 0,
          ),
        );
      }
    }
  }

  void _paintCompare(Canvas canvas) {
    for (final n in compareNotes!) {
      final c = Offset(_noteX(n.fret), _stringY(n.string));
      if (n.isRoot) {
        canvas.drawCircle(
          c,
          dotR + 3,
          Paint()
            ..color = ring
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
      final both = n.inA && n.inB;
      final aOnly = n.inA && !n.inB;
      Color textCol;
      if (both || aOnly) {
        final fill = both ? rootFill : noteFill;
        textCol = both ? rootText : noteText;
        canvas.drawCircle(c, dotR, Paint()..color = fill);
        canvas.drawCircle(
          c,
          dotR,
          Paint()
            ..color = dotStroke
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      } else {
        // B-only — hollow ring in amber over the board background.
        textCol = amber;
        canvas.drawCircle(c, dotR, Paint()..color = dotStroke);
        canvas.drawCircle(
          c,
          dotR,
          Paint()
            ..color = amber
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
      if (label != LabelMode.hide) {
        final text = label == LabelMode.intervals ? n.interval : n.note;
        _text(
          canvas,
          text,
          c,
          Sanctuary.mono(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: textCol,
            letterSpacing: 0,
          ),
        );
      }
    }
  }

  void _text(Canvas canvas, String text, Offset center, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(_FretboardPainter old) => old.signature != signature;
}
