import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../metronome_engine.dart';

const _timeSigs = [2, 3, 4, 5, 6];
const _presets = [
  ('Largo', 50),
  ('Adagio', 68),
  ('Andante', 84),
  ('Moderato', 100),
  ('Allegro', 132),
  ('Vivace', 160),
  ('Presto', 184),
];

String _tempoName(int bpm) {
  if (bpm < 60) return 'Largo';
  if (bpm < 76) return 'Adagio';
  if (bpm < 92) return 'Andante';
  if (bpm < 112) return 'Moderato';
  if (bpm < 140) return 'Allegro';
  if (bpm < 176) return 'Vivace';
  return 'Presto';
}

class MetronomeScreen extends StatefulWidget {
  const MetronomeScreen({super.key});

  @override
  State<MetronomeScreen> createState() => _MetronomeScreenState();
}

class _MetronomeScreenState extends State<MetronomeScreen> {
  final MetronomeEngine _engine = MetronomeEngine();
  int _bpm = 100;
  int _beats = 4;
  int _currentBeat = -1;
  bool _running = false;
  final List<int> _taps = [];

  @override
  void initState() {
    super.initState();
    _engine.bpm = _bpm;
    _engine.beatsPerBar = _beats;
    _engine.onBeat = (b) {
      if (mounted) setState(() => _currentBeat = b);
    };
  }

  @override
  void dispose() {
    _engine.dispose();
    super.dispose();
  }

  void _setBpm(int n) {
    setState(() => _bpm = n.clamp(40, 240));
    _engine.bpm = _bpm;
  }

  void _setBeats(int n) {
    setState(() => _beats = n);
    _engine.setBeatsPerBar(n);
  }

  Future<void> _toggle() async {
    if (_running) {
      _engine.stop();
      setState(() => _running = false);
    } else {
      try {
        await _engine.start();
        if (mounted) setState(() => _running = true);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Audio failed to start: $e')),
          );
        }
      }
    }
  }

  void _tap() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_taps.isNotEmpty && now - _taps.last > 2000) _taps.clear();
    _taps.add(now);
    if (_taps.length > 6) _taps.removeAt(0);
    if (_taps.length >= 2) {
      var sum = 0;
      for (var i = 1; i < _taps.length; i++) {
        sum += _taps[i] - _taps[i - 1];
      }
      _setBpm((60000 / (sum / (_taps.length - 1))).round());
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 20),
          onPressed: () => context.canPop() ? context.pop() : context.go('/games'),
        ),
        title: const Text('Metronome'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Beat indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_beats, (i) {
                    final active = _running && _currentBeat == i;
                    final down = i == 0;
                    final color = down ? cs.primary : cs.secondary;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 80),
                        width: active ? 18 : 12,
                        height: active ? 18 : 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: active
                              ? color
                              : cs.onSurfaceVariant.withValues(alpha: 0.25),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 18),
                Text('$_bpm',
                    style: Sanctuary.display(fontSize: 64, fontWeight: FontWeight.w700, color: cs.onSurface)),
                Text('${_tempoName(_bpm)} · BPM',
                    style: Sanctuary.mono(fontSize: 11, color: cs.onSurfaceVariant)),
                const SizedBox(height: 12),
                Slider(
                  min: 40,
                  max: 240,
                  value: _bpm.toDouble(),
                  onChanged: (v) => _setBpm(v.round()),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _stepBtn(cs, isDark, '−5', () => _setBpm(_bpm - 5)),
                    const SizedBox(width: 6),
                    _stepBtn(cs, isDark, '−1', () => _setBpm(_bpm - 1)),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: _toggle,
                      icon: Icon(_running ? Icons.stop : Icons.play_arrow, size: 18),
                      label: Text(_running ? 'Stop' : 'Start'),
                    ),
                    const SizedBox(width: 10),
                    _stepBtn(cs, isDark, '+1', () => _setBpm(_bpm + 1)),
                    const SizedBox(width: 6),
                    _stepBtn(cs, isDark, '+5', () => _setBpm(_bpm + 5)),
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
                Text('BEATS PER BAR',
                    style: Sanctuary.mono(fontSize: 10, color: cs.onSurfaceVariant)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final n in _timeSigs)
                      _segChip(cs, isDark, '$n/4', n == _beats, () => _setBeats(n)),
                  ],
                ),
                const SizedBox(height: 14),
                Text('FIND A TEMPO',
                    style: Sanctuary.mono(fontSize: 10, color: cs.onSurfaceVariant)),
                const SizedBox(height: 8),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(Sanctuary.radiusMd),
                    onTap: _tap,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isDark ? Sanctuary.glass1 : Sanctuary.lightGlass1,
                        border: Border.all(color: cs.outlineVariant),
                        borderRadius: BorderRadius.circular(Sanctuary.radiusMd),
                      ),
                      child: Text('Tap along to set the BPM',
                          style: TextStyle(color: cs.onSurface, fontSize: 14)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text('TEMPO PRESETS',
              style: Sanctuary.mono(fontSize: 10, color: cs.onSurfaceVariant)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final p in _presets)
                _segChip(cs, isDark, '${p.$1} ${p.$2}', _bpm == p.$2, () => _setBpm(p.$2)),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'The first beat of each bar is accented. Tempo is held steady against a '
            'monotonic clock so it won\'t drift.',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _stepBtn(ColorScheme cs, bool isDark, String label, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(Sanctuary.radiusMd),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? Sanctuary.glass1 : Sanctuary.lightGlass1,
            border: Border.all(color: cs.outlineVariant),
            borderRadius: BorderRadius.circular(Sanctuary.radiusMd),
          ),
          child: Text(label,
              style: Sanctuary.mono(fontSize: 12, color: cs.onSurface, letterSpacing: 0)),
        ),
      ),
    );
  }

  Widget _segChip(ColorScheme cs, bool isDark, String label, bool active, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(Sanctuary.radiusMd),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: active
                ? cs.primary.withValues(alpha: 0.15)
                : (isDark ? Sanctuary.glass1 : Sanctuary.lightGlass1),
            border: Border.all(
                color: active ? cs.primary.withValues(alpha: 0.5) : cs.outlineVariant),
            borderRadius: BorderRadius.circular(Sanctuary.radiusMd),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: active ? cs.primary : cs.onSurfaceVariant)),
        ),
      ),
    );
  }
}
