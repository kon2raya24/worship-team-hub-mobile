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
  bool _pad = true;
  bool _bass = true;
  bool _drums = true;
  bool _running = false;
  bool _loading = false;
  int _currentIndex = -1;

  @override
  void initState() {
    super.initState();
    _engine.onChord = (i) {
      if (mounted) setState(() => _currentIndex = i);
    };
  }

  @override
  void dispose() {
    _engine.dispose();
    super.dispose();
  }

  List<DiatonicChord> _chords() {
    final scale = kScales.firstWhere((s) => s.id == _quality, orElse: () => kScales.first);
    final all = buildDiatonicChords(_root, scale);
    final degrees = _progressions.firstWhere((p) => p.$1 == _progId).$2;
    return [for (final d in degrees) all.firstWhere((c) => c.degree == d)];
  }

  Future<void> _toggle() async {
    if (_running) {
      _engine.stop();
      setState(() => _running = false);
    } else {
      setState(() => _loading = true);
      await _engine.start();
      if (mounted) {
        setState(() {
          _running = true;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chords = _chords();

    // Keep the engine in sync with the controls (plain field writes; the
    // scheduler reads bpm/toggles live, and start() rebuilds voices if the
    // chord set changed).
    _engine
      ..chords = [for (final c in chords) c.pcs]
      ..bpm = _bpm
      ..barsPerChord = _bars
      ..padOn = _pad
      ..bassOn = _bass
      ..drumsOn = _drums;

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
            padding: const EdgeInsets.all(16),
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
                const SizedBox(height: 14),
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
                const SizedBox(height: 14),
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
              ],
            ),
          ),
          const SizedBox(height: 12),
          GlassCard(
            padding: const EdgeInsets.all(16),
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
                    Text('BARS / CHORD',
                        style: Sanctuary.mono(fontSize: 10, color: cs.onSurfaceVariant)),
                    const SizedBox(width: 12),
                    _chip(cs, isDark, '1', _bars == 1, () => setState(() => _bars = 1)),
                    const SizedBox(width: 6),
                    _chip(cs, isDark, '2', _bars == 2, () => setState(() => _bars = 2)),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _chip(cs, isDark, 'Pad', _pad, () => setState(() => _pad = !_pad)),
                    _chip(cs, isDark, 'Bass', _bass, () => setState(() => _bass = !_bass)),
                    _chip(cs, isDark, 'Drums', _drums, () => setState(() => _drums = !_drums)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: FilledButton.icon(
              onPressed: _loading ? null : _toggle,
              icon: Icon(_running ? Icons.stop : Icons.play_arrow, size: 18),
              label: Text(_loading ? 'Loading…' : (_running ? 'Stop' : 'Play')),
            ),
          ),
          const SizedBox(height: 16),
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
            'A simplified, synthesised backing track (pad + bass + drums). Loop a '
            'progression and solo over it with the matching scale on the Fretboard. '
            'For richer sampled instruments, use the web app.',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _chordCard(ColorScheme cs, DiatonicChord c, bool active) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      width: 84,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: active ? cs.primary.withValues(alpha: 0.15) : cs.surface.withValues(alpha: 0.4),
        border: Border.all(
            color: active ? cs.primary.withValues(alpha: 0.6) : cs.outlineVariant),
        borderRadius: BorderRadius.circular(Sanctuary.radiusLg),
      ),
      child: Column(
        children: [
          Text(c.roman, style: Sanctuary.mono(fontSize: 10, color: cs.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text(c.name,
              style: Sanctuary.display(
                  fontSize: 18, color: active ? cs.primary : cs.onSurface)),
          Text(c.notes.join(' '),
              style: Sanctuary.mono(fontSize: 9, color: cs.onSurfaceVariant, letterSpacing: 0)),
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
