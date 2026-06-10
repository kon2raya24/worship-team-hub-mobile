import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../backing_track_engine.dart';
import '../fretboard_data.dart';

const _progressions = <(String, List<int>)>[
  ('Pop', [1, 5, 6, 4]),
  ('Worship', [1, 4, 6, 5]),
  ('Axis', [6, 4, 1, 5]),
  ('Classic', [1, 4, 5]),
  ("'50s", [1, 6, 4, 5]),
  ('ii–V–I', [2, 5, 1]),
];

const _styles44 = <(String, String)>[
  ('none', 'Off'),
  ('pop', 'Pop'),
  ('rock', 'Rock'),
  ('ballad', 'Ballad'),
  ('funk', 'Funk'),
  ('dance', 'Dance'),
  ('halftime', 'Half-time'),
  ('ride', 'Ride'),
];
const _styles68 = <(String, String)>[
  ('none', 'Off'),
  ('ballad', 'Ballad'),
  ('rock', 'Rock'),
  ('march', 'March'),
];
const _feels = <(String, String)>[
  ('sustained', 'Sustained'),
  ('pulse', 'Pulse'),
  ('arpeggio', 'Arpeggio'),
];
const _colors = <(String, String)>[
  ('triads', 'Triads'),
  ('sevenths', '7ths'),
  ('lush', 'Lush'),
];
const _voicings = <(String, String)>[
  ('smooth', 'Smooth'),
  ('close', 'Close'),
  ('spread', 'Spread'),
];
const _energyLabels = ['Sparse', 'Groove', 'Full', 'Push'];
const _fillOpts = <(int, String)>[(0, 'Off'), (2, '2 bars'), (4, '4 bars'), (8, '8 bars')];
const _countInOpts = <(int, String)>[(0, 'Off'), (1, '1 bar'), (2, '2 bars')];

/// Voice-lead a chord sequence: pick each chord's inversion so its voices
/// move minimally from the previous chord, instead of re-stacking every chord
/// in the same octave (the single biggest "robotic" tell). "spread" then
/// drops the lowest voice an octave for an open, pad-like spacing.
List<List<int>> voiceLead(List<List<int>> seq, String mode) {
  if (mode == 'close') {
    return [for (final pcs in seq) [for (final pc in pcs) 60 + pc]];
  }
  List<int>? prev;
  final out = <List<int>>[];
  for (final pcs in seq) {
    var best = <int>[];
    var bestScore = double.infinity;
    for (var inv = 0; inv < pcs.length; inv++) {
      final order = [...pcs.sublist(inv), ...pcs.sublist(0, inv)];
      // First voice lands in [55, 66]; the rest stack strictly upward.
      final notes = [55 + ((order[0] - 55) % 12 + 12) % 12];
      for (var i = 1; i < order.length; i++) {
        var up = ((order[i] - notes[i - 1]) % 12 + 12) % 12;
        if (up == 0) up = 12;
        notes.add(notes[i - 1] + up);
      }
      final p = prev;
      double score;
      if (p == null) {
        final mean = notes.fold(0, (a, b) => a + b) / notes.length;
        score = (mean - 64).abs();
      } else {
        score = 0;
        for (final x in notes) {
          score += p.map((q) => (x - q).abs()).reduce((a, b) => a < b ? a : b);
        }
      }
      if (score < bestScore) {
        bestScore = score;
        best = notes;
      }
    }
    prev = best;
    out.add(mode == 'spread' ? [best[0] - 12, ...best.sublist(1)] : best);
  }
  return out;
}

class BackingTrackScreen extends StatefulWidget {
  const BackingTrackScreen({super.key});

  @override
  State<BackingTrackScreen> createState() => _BackingTrackScreenState();
}

class _BackingTrackScreenState extends State<BackingTrackScreen> {
  final BackingTrackEngine _engine = BackingTrackEngine();
  String _root = 'G';
  String _quality = 'major'; // 'major' | 'natural-minor'
  String _progId = 'Pop';
  int _bpm = 90;
  int _bars = 1;
  String _meter = '4/4';
  String _style = 'pop';
  String _feel = 'pulse';
  String _color = 'triads';
  String _voicing = 'smooth';
  int _energy = 2;
  bool _autoBuild = true;
  int _countIn = 1;
  int _humanize = 60;
  bool _walkups = true;
  int _fillEvery = 4;
  bool _pad = true;
  bool _bass = true;
  bool _running = false;
  bool _loading = false;
  int _currentIndex = -1;
  int _energyNow = -1;

  @override
  void initState() {
    super.initState();
    _engine.onChord = (i) {
      if (mounted) setState(() => _currentIndex = i);
    };
    _engine.onEnergy = (l) {
      if (mounted) setState(() => _energyNow = l);
    };
  }

  @override
  void dispose() {
    _engine.dispose();
    super.dispose();
  }

  ScaleDef get _scale =>
      kScales.firstWhere((s) => s.id == _quality, orElse: () => kScales.first);

  List<DiatonicChord> _chords() {
    final all = buildDiatonicChords(_root, _scale);
    final degrees = _progressions.firstWhere((p) => p.$1 == _progId).$2;
    return [for (final d in degrees) all.firstWhere((c) => c.degree == d)];
  }

  /// Triad pcs extended by the chord color: diatonic 7th, or an add9 ("lush")
  /// worship voicing. Dim/aug chords stay plain triads in lush mode.
  List<int> _coloredPcs(DiatonicChord c) {
    final pcs = List<int>.of(c.pcs);
    final rootPc = pitchClass(_root) ?? 0;
    final deg = _scale.intervals;
    if (_color == 'sevenths') {
      pcs.add((rootPc + deg[(c.degree + 5) % 7]) % 12);
    } else if (_color == 'lush' && (c.quality == 'maj' || c.quality == 'min')) {
      pcs.add((rootPc + deg[c.degree % 7]) % 12);
    }
    return pcs;
  }

  String _colorName(DiatonicChord c) => _color == 'sevenths'
      ? c.seventh
      : (_color == 'lush' && (c.quality == 'maj' || c.quality == 'min'))
          ? '${c.name}add9'
          : c.name;

  void _chooseMeter(String m) => setState(() {
        _meter = m;
        final opts = m == '6/8' ? _styles68 : _styles44;
        if (!opts.any((s) => s.$1 == _style)) _style = m == '6/8' ? 'ballad' : 'pop';
      });

  Future<void> _toggle() async {
    if (_running) {
      _engine.stop();
      setState(() => _running = false);
    } else {
      setState(() => _loading = true);
      try {
        await _engine.start();
        if (mounted) {
          setState(() {
            _running = true;
            _loading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() => _loading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Audio failed to start: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chords = _chords();
    final styles = _meter == '6/8' ? _styles68 : _styles44;

    // Keep the engine in sync with the controls (plain field writes; the
    // scheduler reads bpm/toggles live, and start() rebuilds voices if the
    // chord set changed).
    final colored = [for (final c in chords) _coloredPcs(c)];
    _engine
      ..chords = voiceLead(colored, _voicing)
      ..triads = colored
      ..bpm = _bpm
      ..barsPerChord = _bars
      ..meter = _meter
      ..style = _style
      ..feel = _feel
      ..energy = _energy
      ..autoBuild = _autoBuild
      ..countIn = _countIn
      ..humanize = _humanize
      ..walkups = _walkups
      ..fillEvery = _fillEvery
      ..padOn = _pad
      ..bassOn = _bass;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 20),
          onPressed: () => context.canPop() ? context.pop() : context.go('/games'),
        ),
        title: const Text('Backing Track'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GlassCard(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('KEY', style: Sanctuary.mono(fontSize: 10, color: cs.onSurfaceVariant)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final r in kRoots)
                      _chip(cs, isDark, r, r == _root, () => setState(() => _root = r), mono: true),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text('TONALITY',
                        style: Sanctuary.mono(fontSize: 10, color: cs.onSurfaceVariant)),
                    const SizedBox(width: 12),
                    _chip(cs, isDark, 'Major', _quality == 'major',
                        () => setState(() => _quality = 'major')),
                    const SizedBox(width: 6),
                    _chip(cs, isDark, 'Minor', _quality == 'natural-minor',
                        () => setState(() => _quality = 'natural-minor')),
                  ],
                ),
                const SizedBox(height: 10),
                Text('PROGRESSION',
                    style: Sanctuary.mono(fontSize: 10, color: cs.onSurfaceVariant)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final p in _progressions)
                      _chip(cs, isDark, p.$1, p.$1 == _progId,
                          () => setState(() => _progId = p.$1)),
                  ],
                ),
                const SizedBox(height: 10),
                Text('CHORD COLOR',
                    style: Sanctuary.mono(fontSize: 10, color: cs.onSurfaceVariant)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final c in _colors)
                      _chip(cs, isDark, c.$2, c.$1 == _color,
                          () => setState(() => _color = c.$1)),
                  ],
                ),
                const SizedBox(height: 10),
                Text('VOICING',
                    style: Sanctuary.mono(fontSize: 10, color: cs.onSurfaceVariant)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final v in _voicings)
                      _chip(cs, isDark, v.$2, v.$1 == _voicing,
                          () => setState(() => _voicing = v.$1)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GlassCard(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TEMPO — $_bpm BPM',
                    style: Sanctuary.mono(fontSize: 10, color: cs.onSurfaceVariant)),
                Slider(
                  min: 50,
                  max: 200,
                  value: _bpm.toDouble(),
                  onChanged: (v) => setState(() => _bpm = v.round()),
                ),
                Row(
                  children: [
                    Text('METER', style: Sanctuary.mono(fontSize: 10, color: cs.onSurfaceVariant)),
                    const SizedBox(width: 12),
                    _chip(cs, isDark, '4/4', _meter == '4/4', () => _chooseMeter('4/4')),
                    const SizedBox(width: 6),
                    _chip(cs, isDark, '6/8', _meter == '6/8', () => _chooseMeter('6/8')),
                    const SizedBox(width: 16),
                    Text('BARS', style: Sanctuary.mono(fontSize: 10, color: cs.onSurfaceVariant)),
                    const SizedBox(width: 12),
                    _chip(cs, isDark, '1', _bars == 1, () => setState(() => _bars = 1)),
                    const SizedBox(width: 6),
                    _chip(cs, isDark, '2', _bars == 2, () => setState(() => _bars = 2)),
                  ],
                ),
                const SizedBox(height: 10),
                Text('FEEL', style: Sanctuary.mono(fontSize: 10, color: cs.onSurfaceVariant)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final f in _feels)
                      _chip(cs, isDark, f.$2, f.$1 == _feel, () => setState(() => _feel = f.$1)),
                  ],
                ),
                const SizedBox(height: 10),
                Text('DRUMS', style: Sanctuary.mono(fontSize: 10, color: cs.onSurfaceVariant)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final st in styles)
                      _chip(cs, isDark, st.$2, st.$1 == _style,
                          () => setState(() => _style = st.$1)),
                  ],
                ),
                const SizedBox(height: 10),
                // Build cycles the arrangement (sparse → groove → full → push →
                // drop) each pass; the live level lights up while it plays.
                Text('ENERGY', style: Sanctuary.mono(fontSize: 10, color: cs.onSurfaceVariant)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _chip(cs, isDark, '🔄 Build', _autoBuild,
                        () => setState(() => _autoBuild = true)),
                    for (var i = 0; i < _energyLabels.length; i++)
                      _chip(
                        cs,
                        isDark,
                        _energyLabels[i],
                        _autoBuild ? (_running && _energyNow == i) : _energy == i,
                        () => setState(() {
                          _autoBuild = false;
                          _energy = i;
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text('FILL EVERY',
                    style: Sanctuary.mono(fontSize: 10, color: cs.onSurfaceVariant)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final f in _fillOpts)
                      _chip(cs, isDark, f.$2, f.$1 == _fillEvery,
                          () => setState(() => _fillEvery = f.$1)),
                  ],
                ),
                const SizedBox(height: 10),
                Text('COUNT-IN',
                    style: Sanctuary.mono(fontSize: 10, color: cs.onSurfaceVariant)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final o in _countInOpts)
                      _chip(cs, isDark, o.$2, o.$1 == _countIn,
                          () => setState(() => _countIn = o.$1)),
                  ],
                ),
                const SizedBox(height: 10),
                Text('HUMANIZE — ${_humanize == 0 ? "machine-tight" : "$_humanize%"}',
                    style: Sanctuary.mono(fontSize: 10, color: cs.onSurfaceVariant)),
                Slider(
                  min: 0,
                  max: 100,
                  value: _humanize.toDouble(),
                  onChanged: (v) => setState(() => _humanize = v.round()),
                ),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _chip(cs, isDark, 'Pad', _pad, () => setState(() => _pad = !_pad)),
                    _chip(cs, isDark, 'Bass', _bass, () => setState(() => _bass = !_bass)),
                    _chip(cs, isDark, 'Walk-ups', _walkups,
                        () => setState(() => _walkups = !_walkups)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: FilledButton.icon(
              onPressed: _loading ? null : _toggle,
              icon: Icon(_running ? Icons.stop : Icons.play_arrow, size: 18),
              label: Text(_loading ? 'Loading…' : (_running ? 'Stop' : 'Play')),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < chords.length; i++)
                _chordCard(cs, chords[i], _running && _currentIndex == i),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'A synthesised band: chords, style-matched bass, and drums with fills. '
            '🔄 Build grows the band each pass — sparse, groove, full, push, then '
            'back down — like a real arrangement. Solo over it with the matching '
            'scale on the Fretboard.',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _chordCard(ColorScheme cs, DiatonicChord c, bool active) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      constraints: const BoxConstraints(minWidth: 60),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      decoration: BoxDecoration(
        color: active ? cs.primary.withValues(alpha: 0.15) : cs.surface.withValues(alpha: 0.4),
        border: Border.all(
            color: active ? cs.primary.withValues(alpha: 0.6) : cs.outlineVariant),
        borderRadius: BorderRadius.circular(Sanctuary.radiusMd),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(c.roman, style: Sanctuary.mono(fontSize: 9, color: cs.onSurfaceVariant)),
          Text(_colorName(c),
              style: Sanctuary.display(
                  fontSize: 15, color: active ? cs.primary : cs.onSurface)),
          Text(c.notes.join(' '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Sanctuary.mono(fontSize: 8, color: cs.onSurfaceVariant, letterSpacing: 0)),
        ],
      ),
    );
  }

  Widget _chip(ColorScheme cs, bool isDark, String label, bool active, VoidCallback onTap,
      {bool mono = false}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(Sanctuary.radiusMd),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minWidth: 40),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active
                ? cs.primary.withValues(alpha: 0.15)
                : (isDark ? Sanctuary.glass1 : Sanctuary.lightGlass1),
            border: Border.all(
                color: active ? cs.primary.withValues(alpha: 0.5) : cs.outlineVariant),
            borderRadius: BorderRadius.circular(Sanctuary.radiusMd),
          ),
          child: mono
              ? Text(label,
                  style: Sanctuary.mono(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: active ? cs.primary : cs.onSurface,
                      letterSpacing: 0))
              : Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: active ? cs.primary : cs.onSurfaceVariant)),
        ),
      ),
    );
  }
}
