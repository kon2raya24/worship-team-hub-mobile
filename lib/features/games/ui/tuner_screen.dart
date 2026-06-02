import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../tuner_engine.dart';

const int _inTune = 5; // cents within this counts as in tune

class TunerScreen extends StatefulWidget {
  const TunerScreen({super.key});

  @override
  State<TunerScreen> createState() => _TunerScreenState();
}

class _TunerScreenState extends State<TunerScreen> {
  final TunerEngine _engine = TunerEngine();
  TunerReading? _reading;
  bool _listening = false;
  String? _error;
  int _a4 = 440;

  @override
  void initState() {
    super.initState();
    _engine.onReading = (r) {
      if (mounted) setState(() => _reading = r);
    };
    _engine.onError = (m) {
      if (mounted) {
        setState(() {
          _error = m;
          _listening = false;
        });
      }
    };
  }

  @override
  void dispose() {
    _engine.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_listening) {
      await _engine.stop();
      if (mounted) setState(() => _listening = false);
    } else {
      setState(() => _error = null);
      final ok = await _engine.start();
      if (mounted) setState(() => _listening = ok);
    }
  }

  void _setA4(int hz) {
    setState(() => _a4 = hz.clamp(415, 466));
    _engine.a4 = _a4.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final green = isDark ? Sanctuary.success : Sanctuary.lightSuccess;
    final r = _reading;
    final cents = r?.cents ?? 0;
    final inTune = r != null && cents.abs() <= _inTune;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 20),
          onPressed: () => context.canPop() ? context.pop() : context.go('/games'),
        ),
        title: const Text('Tuner'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                SizedBox(
                  height: 84,
                  child: Center(
                    child: r == null
                        ? Text('—',
                            style: Sanctuary.display(
                                fontSize: 56,
                                fontWeight: FontWeight.w700,
                                color: cs.onSurfaceVariant.withValues(alpha: 0.4)))
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.note.replaceAll('#', '♯'),
                                  style: Sanctuary.display(
                                      fontSize: 72,
                                      fontWeight: FontWeight.w700,
                                      color: inTune ? green : cs.onSurface)),
                              const SizedBox(width: 2),
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text('${r.octave}',
                                    style: Sanctuary.mono(
                                        fontSize: 20, color: cs.onSurfaceVariant)),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  !_listening
                      ? 'Mic off'
                      : r == null
                          ? 'Play a note…'
                          : inTune
                              ? 'In tune'
                              : cents < 0
                                  ? '$cents cents · flat ♭ — tune up'
                                  : '+$cents cents · sharp ♯ — tune down',
                  style: Sanctuary.mono(
                      fontSize: 11, color: inTune ? green : cs.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                _meter(cs, green, r, cents, inTune),
                const SizedBox(height: 12),
                Text(
                  r == null
                      ? '— Hz'
                      : '${r.frequency.toStringAsFixed(1)} Hz   ${cents > 0 ? '+' : ''}$cents¢',
                  style: Sanctuary.mono(fontSize: 13, color: cs.onSurfaceVariant, letterSpacing: 0),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _toggle,
                  icon: Icon(_listening ? Icons.mic_off : Icons.mic, size: 18),
                  label: Text(_listening ? 'Stop listening' : 'Start mic'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: TextStyle(color: cs.error, fontSize: 13)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('REFERENCE PITCH',
                    style: Sanctuary.mono(fontSize: 10, color: cs.onSurfaceVariant)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _roundBtn(cs, isDark, Icons.remove, () => _setA4(_a4 - 1)),
                    const SizedBox(width: 12),
                    Text('$_a4',
                        style: Sanctuary.display(fontSize: 22, color: cs.onSurface)),
                    Text(' Hz', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                    const SizedBox(width: 12),
                    _roundBtn(cs, isDark, Icons.add, () => _setA4(_a4 + 1)),
                    const Spacer(),
                    if (_a4 != 440)
                      TextButton(onPressed: () => _setA4(440), child: const Text('440')),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Standard guitar: E2 A2 D3 G3 B3 E4. For bass and low strings, tune the '
            '12th-fret harmonic (one octave up) for a cleaner reading. Audio stays on '
            'your device — nothing is recorded or uploaded.',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _meter(ColorScheme cs, Color green, TunerReading? r, int cents, bool inTune) {
    return LayoutBuilder(
      builder: (context, cons) {
        final w = cons.maxWidth;
        final nx = (0.5 + cents.clamp(-50, 50) / 100) * w;
        return SizedBox(
          height: 48,
          child: Stack(
            children: [
              // Track
              Positioned(
                left: 0,
                right: 0,
                top: 21,
                height: 6,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              // In-tune band (±5 cents → 10% of width)
              Positioned(
                left: w * 0.45,
                width: w * 0.10,
                top: 21,
                height: 6,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: green.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              // Centre tick
              Positioned(
                left: w * 0.5 - 0.5,
                top: 12,
                height: 24,
                width: 1,
                child: ColoredBox(color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
              ),
              // Needle
              if (r != null)
                Positioned(
                  left: nx - 2,
                  top: 6,
                  height: 36,
                  width: 4,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: inTune ? green : cs.onSurface,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _roundBtn(ColorScheme cs, bool isDark, IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(Sanctuary.radiusMd),
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isDark ? Sanctuary.glass1 : Sanctuary.lightGlass1,
            border: Border.all(color: cs.outlineVariant),
            borderRadius: BorderRadius.circular(Sanctuary.radiusMd),
          ),
          child: Icon(icon, size: 18, color: cs.onSurface),
        ),
      ),
    );
  }
}
