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

  ScaleDef get _scale =>
      kScales.firstWhere((s) => s.id == _scaleId, orElse: () => kScales.first);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scale = _scale;
    final notes = buildScaleFretboard(_root, scale);
    final names = scaleNotes(_root, scale);

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
          Text('SCALE', style: Sanctuary.mono(fontSize: 10, color: cs.onSurfaceVariant)),
          const SizedBox(height: 8),
          _scaleDropdown(cs, isDark),
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
                      label: _label,
                      signature: '$_root|$_scaleId|${_label.index}|$isDark',
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
      ),
    );
  }

  Widget _keyChip(ColorScheme cs, bool isDark, String r) {
    final selected = r == _root;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(Sanctuary.radiusMd),
        onTap: () => setState(() => _root = r),
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

  Widget _scaleDropdown(ColorScheme cs, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? Sanctuary.glass1 : Sanctuary.lightGlass1,
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(Sanctuary.radiusMd),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _scaleId,
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
            if (v != null) setState(() => _scaleId = v);
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
    required this.label,
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
  });

  final List<FretNote> notes;
  final LabelMode label;
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

    // Note dots.
    for (final n in notes) {
      final c = Offset(_noteX(n.fret), _stringY(n.string));
      canvas.drawCircle(c, dotR, Paint()..color = n.isRoot ? rootFill : noteFill);
      // Separating ring so adjacent dots stay distinct.
      canvas.drawCircle(
        c,
        dotR,
        Paint()
          ..color = dotStroke
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      if (label != LabelMode.hide) {
        final text = label == LabelMode.intervals ? n.interval : n.note;
        _text(
          canvas,
          text,
          c,
          Sanctuary.mono(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: n.isRoot ? rootText : noteText,
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
