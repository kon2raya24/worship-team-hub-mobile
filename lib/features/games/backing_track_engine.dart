import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

// ── Arrangement data (mirrors web lib/use-backing-track.ts) ─────────────────

/// Energy shapes the whole arrangement: how hard everything hits, which drum
/// pieces play, how busy the bass line is, and whether fills happen.
class _Energy {
  final double vel;
  final String drums; // tick | low | full | push
  final int bassBusy;
  final bool fills;
  const _Energy(this.vel, this.drums, this.bassBusy, this.fills);
}

const _energyConf = <_Energy>[
  _Energy(0.72, 'tick', 0, false), // sparse
  _Energy(0.85, 'low', 1, false), // groove
  _Energy(1.0, 'full', 2, true), // full
  _Energy(1.08, 'push', 2, true), // push
];
// Auto-build steps this arc once per pass through the progression:
// verse → build → chorus → peak → peak → drop back down, then around again.
const _buildArc = [0, 1, 2, 3, 3, 1];

class _DrumPattern {
  final Set<int> kick;
  final Set<int> snare;
  final Set<int> hat;
  final Set<int> openhat;
  final Set<int> ride;
  final Set<int> rim;
  final bool crashFirst;
  const _DrumPattern({
    this.kick = const {},
    this.snare = const {},
    this.hat = const {},
    this.openhat = const {},
    this.ride = const {},
    this.rim = const {},
    this.crashFirst = false,
  });
}

// 4/4 grooves (eighth-note grid, indices 0..7).
const _patterns44 = <String, _DrumPattern>{
  'pop': _DrumPattern(kick: {0, 4}, snare: {2, 6}, hat: {0, 1, 2, 3, 4, 5, 6, 7}, crashFirst: true),
  'rock': _DrumPattern(kick: {0, 4, 5}, snare: {2, 6}, hat: {0, 1, 2, 3, 4, 5, 6, 7}, openhat: {7}, crashFirst: true),
  'ballad': _DrumPattern(kick: {0}, snare: {4}, hat: {0, 2, 4, 6}, crashFirst: true),
  'funk': _DrumPattern(kick: {0, 3, 4, 6}, snare: {2, 6}, hat: {0, 1, 2, 3, 4, 5, 6, 7}, rim: {5}),
  'dance': _DrumPattern(kick: {0, 2, 4, 6}, snare: {2, 6}, openhat: {1, 3, 5, 7}, crashFirst: true),
  'halftime': _DrumPattern(kick: {0, 5}, snare: {4}, hat: {0, 1, 2, 3, 4, 5, 6, 7}, crashFirst: true),
  'ride': _DrumPattern(kick: {0, 4}, snare: {2, 6}, ride: {0, 1, 2, 3, 4, 5, 6, 7}, crashFirst: true),
};
// 6/8 grooves (eighth-note grid, indices 0..5; felt in two pulses on 0 and 3).
const _patterns68 = <String, _DrumPattern>{
  'ballad': _DrumPattern(kick: {0}, snare: {3}, hat: {0, 1, 2, 3, 4, 5}, crashFirst: true),
  'rock': _DrumPattern(kick: {0, 3}, snare: {3}, hat: {0, 1, 2, 3, 4, 5}, openhat: {5}, crashFirst: true),
  'march': _DrumPattern(kick: {0, 3}, snare: {3}, hat: {0, 2, 3, 5}, crashFirst: true),
};

// Tom-run fill and its alternate, a snare roll building into the next section.
const _tomFill44 = <(int, int)>[(4, 0), (5, 0), (6, 1), (7, 2)]; // (eighth, tom hi/mid/lo)
const _tomFill68 = <(int, int)>[(3, 0), (4, 1), (5, 2)];
const _snareFill44 = <(int, double)>[(4, 0.5), (5, 0.62), (6, 0.78), (7, 0.95)];
const _snareFill68 = <(int, double)>[(3, 0.55), (4, 0.72), (5, 0.92)];

/// Style-specific bass lines on the eighth grid. `busy` marks pickup notes
/// that only play at full bass busyness (energy ≥ full).
class _BassStep {
  final int e;
  final String tone; // root | third | fifth | octave
  final int len; // eighths
  final double vel;
  final int busy;
  const _BassStep(this.e, this.tone, this.len, {this.vel = 1, this.busy = 0});
}

const _bass44 = <String, List<_BassStep>>{
  'default': [
    _BassStep(0, 'root', 4),
    _BassStep(4, 'fifth', 3),
    _BassStep(7, 'octave', 1, vel: 0.75, busy: 2),
  ],
  'ballad': [_BassStep(0, 'root', 8)],
  'pump': [
    _BassStep(0, 'root', 2),
    _BassStep(2, 'root', 2, vel: 0.85),
    _BassStep(4, 'root', 2),
    _BassStep(6, 'root', 2, vel: 0.85),
  ],
  'funk': [
    _BassStep(0, 'root', 2),
    _BassStep(3, 'octave', 1, vel: 0.85, busy: 2),
    _BassStep(4, 'fifth', 2),
    _BassStep(6, 'root', 1, vel: 0.9),
    _BassStep(7, 'octave', 1, vel: 0.75, busy: 2),
  ],
  'disco': [
    _BassStep(0, 'root', 1),
    _BassStep(1, 'octave', 1, vel: 0.8),
    _BassStep(2, 'root', 1),
    _BassStep(3, 'octave', 1, vel: 0.8),
    _BassStep(4, 'root', 1),
    _BassStep(5, 'octave', 1, vel: 0.8),
    _BassStep(6, 'root', 1),
    _BassStep(7, 'octave', 1, vel: 0.8),
  ],
  'halftime': [
    _BassStep(0, 'root', 5),
    _BassStep(5, 'root', 2, vel: 0.9),
    _BassStep(7, 'fifth', 1, vel: 0.75, busy: 2),
  ],
};
const _bass68 = <String, List<_BassStep>>{
  'default': [_BassStep(0, 'root', 3), _BassStep(3, 'fifth', 3)],
  'ballad': [_BassStep(0, 'root', 6)],
  'pump': [
    _BassStep(0, 'root', 2),
    _BassStep(2, 'root', 1, vel: 0.8, busy: 2),
    _BassStep(3, 'fifth', 2),
    _BassStep(5, 'octave', 1, vel: 0.8, busy: 2),
  ],
};
// Which bass line each drum style wants.
const _bassForStyle = <String, String>{
  'none': 'default',
  'pop': 'default',
  'rock': 'pump',
  'ballad': 'ballad',
  'funk': 'funk',
  'dance': 'disco',
  'halftime': 'halftime',
  'ride': 'default',
  'march': 'pump',
};

/// Backing-track engine (a synthesised Flutter port of the web backing track).
///
/// The web version uses smplr soundfonts + sampled kits, which have no Flutter
/// equivalent, so every voice is synthesised in-Dart as WAV bytes and played
/// through flutter_soloud (low-latency, polyphonic, plays from memory). It
/// mirrors the web arrangement: drum styles in 4/4 and 6/8, energy levels with
/// an auto-build arc, style-specific bass lines, a fill every 4 bars with a
/// crash landing, ghost notes, velocity humanisation, a one-bar count-in, and
/// chord feels (sustained / pulse / arpeggio). A drift-free lookahead loop
/// (like the metronome) steps at the eighth note.
class BackingTrackEngine {
  final Map<String, AudioSource> _padFor = {}; // sustained pad, key: pcs joined
  final Map<String, AudioSource> _hitFor = {}; // short chord hit (pulse feel)
  final Map<int, AudioSource> _toneFor = {}; // arpeggio tones, key: midi note
  final Map<int, AudioSource> _bassFor = {}; // key: midi note
  final Map<String, AudioSource> _drumFor = {}; // kick/snare/hat/…/clickHi/clickLo
  List<List<int>> _builtFor = [];
  bool _building = false;

  Timer? _timer;
  final Stopwatch _clock = Stopwatch();
  final math.Random _rng = math.Random();
  double _nextStep = 0;
  int _stepInChord = 0;
  int _chordIndex = 0;
  int _globalStep = 0; // steps since play started — drives bar-level fills
  int _round = 0; // completed passes through the progression — drives auto-build
  int _countLeft = 0; // count-in steps remaining
  bool _loggedFirstStep = false;

  // Live params.
  List<List<int>> chords = []; // absolute pitch classes (triad, or +7th/+9th)
  int bpm = 90;
  int barsPerChord = 1;
  String meter = '4/4'; // '4/4' | '6/8'
  String style = 'pop'; // drum style id, 'none' = drums off
  String feel = 'sustained'; // sustained | pulse | arpeggio
  int energy = 2; // 0..3, used when autoBuild is off
  bool autoBuild = true;
  bool countIn = true;
  bool padOn = true;
  bool bassOn = true;

  void Function(int chordIndex)? onChord;
  void Function(int level)? onEnergy; // energy level now sounding (-1 stopped)

  bool get running => _timer != null;

  Future<void> _ensureBuilt() async {
    if (_building) return;
    if (_listEq(_builtFor, chords) && _padFor.isNotEmpty) return;
    _building = true;
    final s = SoLoud.instance;
    if (!s.isInitialized) await s.init();

    // Drums + clicks are chord-independent — build once.
    if (_drumFor.isEmpty) {
      Future<void> add(String k, List<double> w) async =>
          _drumFor[k] = await s.loadMem('bt-$k.wav', _wav(w));
      await add('kick', _kickWav());
      await add('snare', _snareWav());
      await add('hat', _noiseWav(0.05, 60, 0.32));
      await add('openhat', _noiseWav(0.32, 13, 0.26));
      await add('crash', _noiseWav(1.1, 3.5, 0.34));
      await add('ride', _rideWav());
      await add('rim', _rimWav());
      await add('tomHi', _tomWav(210));
      await add('tomMid', _tomWav(150));
      await add('tomLo', _tomWav(105));
      await add('clickHi', _clickWav(1500));
      await add('clickLo', _clickWav(1000));
    }

    // Rebuild per-chord pad/hit/arp/bass sources for the current progression.
    for (final src in [..._padFor.values, ..._hitFor.values, ..._toneFor.values, ..._bassFor.values]) {
      s.disposeSource(src);
    }
    _padFor.clear();
    _hitFor.clear();
    _toneFor.clear();
    _bassFor.clear();

    for (final chord in chords) {
      final key = chord.join(',');
      if (!_padFor.containsKey(key)) {
        _padFor[key] = await s.loadMem('bt-pad-$key.wav', _wav(_chordWav(chord, 2.4, 1.1)));
        _hitFor[key] = await s.loadMem('bt-hit-$key.wav', _wav(_chordWav(chord, 0.8, 3.2)));
      }
      for (final pc in chord) {
        // Arpeggio tones (two octaves) + every bass tone the patterns can ask
        // for (root/third/fifth at 36+pc, octave at 48+root).
        for (final m in [60 + pc, 72 + pc]) {
          _toneFor[m] ??= await s.loadMem(
            'bt-tone-$m.wav',
            _wav(_toneWav(_freq(m), 0.7, const [1.0, 0.5, 0.28, 0.12], gain: 0.22, decay: 3.0)),
          );
        }
        for (final m in [36 + pc, 48 + pc]) {
          _bassFor[m] ??= await s.loadMem(
            'bt-bass-$m.wav',
            _wav(_toneWav(_freq(m), 1.2, const [1.0, 0.45, 0.15], gain: 0.5, decay: 3.0)),
          );
        }
      }
    }
    _builtFor = [for (final c in chords) List<int>.of(c)];
    _building = false;
    debugPrint('[audio] backing track built — ${_padFor.length} pads, '
        '${_bassFor.length} basses, ${_drumFor.length} drums (init=${s.isInitialized})');
  }

  Future<void> start() async {
    if (running) return;
    if (chords.isEmpty) return;
    await _ensureBuilt();
    _stepInChord = 0;
    _chordIndex = 0;
    _globalStep = 0;
    _round = 0;
    _countLeft = countIn ? (meter == '6/8' ? 6 : 8) : 0;
    _clock
      ..reset()
      ..start();
    _nextStep = 0;
    _timer = Timer.periodic(const Duration(milliseconds: 8), (_) => _tick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _clock.stop();
    onChord?.call(-1);
    onEnergy?.call(-1);
  }

  void toggle() => running ? stop() : start();

  void _tick() {
    if (chords.isEmpty) return;
    final stepMs = (60000 / bpm) / 2; // eighth note
    final now = _clock.elapsedMilliseconds.toDouble();
    while (now >= _nextStep) {
      _playStep();
      _nextStep += stepMs;
    }
  }

  void _playStep() {
    final s = SoLoud.instance;
    final compound = meter == '6/8';
    final eighthsPerBar = compound ? 6 : 8;

    // Count-in: one bar of metronome clicks before the band comes in.
    if (_countLeft > 0) {
      final i = eighthsPerBar - _countLeft;
      final accent = compound ? (i == 0 || i == 3) : i == 0;
      if (compound || i.isEven) {
        final src = _drumFor[accent ? 'clickHi' : 'clickLo'];
        if (src != null) s.play(src, volume: accent ? 0.9 : 0.65);
      }
      _countLeft--;
      return;
    }

    final stepsPerChord = barsPerChord * eighthsPerBar;
    final eighth = _stepInChord % eighthsPerBar;
    final step = _stepInChord;
    final index = _chordIndex % chords.length;
    final chord = chords[index];
    // Energy — the manual level, or the auto-build arc stepping each pass.
    final level = autoBuild ? _buildArc[_round % _buildArc.length] : energy.clamp(0, 3);
    final e = _energyConf[level];
    // No two hits land at exactly the same strength — keeps loops alive.
    double human() => 0.94 + _rng.nextDouble() * 0.08;

    if (step == 0) {
      onChord?.call(index);
      onEnergy?.call(level);
    }

    // Chords — sustained pad, quarter-note pulse, or one arp tone per eighth.
    if (padOn) {
      if (feel == 'sustained') {
        if (step == 0) {
          final pad = _padFor[chord.join(',')];
          if (pad != null) s.play(pad, volume: (e.vel * human()).clamp(0.0, 1.0));
        }
      } else if (feel == 'pulse') {
        final onPulse = compound ? (eighth == 0 || eighth == 3) : eighth.isEven;
        if (onPulse) {
          final hit = _hitFor[chord.join(',')];
          if (hit != null) s.play(hit, volume: (e.vel * human() * 0.9).clamp(0.0, 1.0));
        }
      } else {
        // arpeggio — one tone per eighth, climbing an octave each pass
        final n = chord.length;
        final pc = chord[step % n];
        final oct = (step ~/ n).isOdd ? 12 : 0;
        final tone = _toneFor[60 + pc + oct];
        if (tone != null) s.play(tone, volume: (e.vel * human() * 0.9).clamp(0.0, 1.0));
      }
    }

    // Bass — style-specific lines, thinned out at low energy to a whole note.
    if (bassOn) {
      final table = compound ? _bass68 : _bass44;
      final steps = e.bassBusy == 0
          ? table['ballad']!
          : (table[_bassForStyle[style] ?? 'default'] ?? table['default']!);
      for (final st in steps) {
        if (st.e != eighth || st.busy > e.bassBusy) continue;
        final pc = st.tone == 'fifth'
            ? chord[math.min(2, chord.length - 1)]
            : st.tone == 'third'
                ? chord[math.min(1, chord.length - 1)]
                : chord[0];
        final bass = _bassFor[(st.tone == 'octave' ? 48 : 36) + pc];
        if (bass != null) s.play(bass, volume: (e.vel * st.vel * human()).clamp(0.0, 1.0));
      }
    }

    if (style != 'none') _playDrums(s, e, compound, eighthsPerBar, eighth, index);

    if (!_loggedFirstStep) {
      _loggedFirstStep = true;
      debugPrint('[audio] backing track first step — activeVoices='
          '${s.getActiveVoiceCount()} globalVolume=${s.getGlobalVolume()}');
    }

    _globalStep++;
    _stepInChord++;
    if (_stepInChord >= stepsPerChord) {
      _stepInChord = 0;
      _chordIndex = (index + 1) % chords.length;
      if (_chordIndex == 0) _round++; // full pass — auto-build steps the arc
    }
  }

  void _playDrums(SoLoud s, _Energy e, bool compound, int eighthsPerBar, int eighth, int index) {
    final p = (compound ? _patterns68 : _patterns44)[style];
    if (p == null) return;
    void hit(String voice, double accent) {
      final src = _drumFor[voice];
      if (src != null) s.play(src, volume: (e.vel * accent).clamp(0.0, 1.0));
    }

    final bar = _stepInChord ~/ eighthsPerBar;
    final isLoopStart = index == 0 && bar == 0;
    // A fill every 4th bar (alternating toms / snare roll), then a crash
    // landing on the bar after it.
    final globalBar = _globalStep ~/ eighthsPerBar;
    final isFillBar = e.fills && globalBar % 4 == 3;
    final crashBar = isLoopStart || (e.fills && globalBar > 0 && globalBar % 4 == 0);
    if (p.crashFirst && crashBar && eighth == 0) hit('crash', 0.9);
    if (isFillBar && eighth >= (compound ? 3 : 4)) {
      if ((globalBar ~/ 4).isOdd) {
        for (final (fe, v) in compound ? _snareFill68 : _snareFill44) {
          if (fe == eighth) hit('snare', v);
        }
      } else {
        for (final (fe, tom) in compound ? _tomFill68 : _tomFill44) {
          if (fe == eighth) hit(tom == 0 ? 'tomHi' : (tom == 1 ? 'tomMid' : 'tomLo'), 0.95);
        }
      }
      return;
    }
    // Cymbal hands never hit twice at the same strength.
    final cymAcc = (eighth.isOdd ? 0.52 : 0.78) + _rng.nextDouble() * 0.12;
    void pulse() {
      if (p.hat.contains(eighth)) hit('hat', cymAcc);
      if (p.ride.contains(eighth)) hit('ride', cymAcc);
    }

    // tick = just the cymbal pulse; low = kick + sidestick backbeat until the
    // song opens up; full = the written groove; push = full + open-hat lift.
    if (e.drums == 'tick') {
      pulse();
      return;
    }
    if (e.drums == 'low') {
      if (p.kick.contains(eighth)) hit('kick', 1);
      if (p.snare.contains(eighth)) hit('rim', 0.85);
      pulse();
      return;
    }
    if (p.kick.contains(eighth)) hit('kick', 1);
    if (p.snare.contains(eighth)) {
      hit('snare', 1);
    } else if (!compound && (eighth == 3 || eighth == 7) && _rng.nextDouble() < 0.18) {
      hit('snare', 0.22); // ghost note between backbeats
    }
    if (p.rim.contains(eighth)) hit('rim', 0.8);
    pulse();
    if (p.openhat.contains(eighth)) {
      hit('openhat', 0.8);
    } else if (e.drums == 'push' && eighth == (compound ? 5 : 7)) {
      hit('openhat', 0.85); // open hat lifting into the next bar
    }
  }

  void dispose() {
    _timer?.cancel();
    final s = SoLoud.instance;
    for (final src in [
      ..._padFor.values,
      ..._hitFor.values,
      ..._toneFor.values,
      ..._bassFor.values,
      ..._drumFor.values,
    ]) {
      s.disposeSource(src);
    }
  }

  bool _listEq(List<List<int>> a, List<List<int>> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].length != b[i].length) return false;
      for (var j = 0; j < a[i].length; j++) {
        if (a[i][j] != b[i][j]) return false;
      }
    }
    return true;
  }

  // ── In-Dart synthesis ─────────────────────────────────────────────────────

  double _freq(int midi) => 440 * math.pow(2, (midi - 69) / 12).toDouble();

  /// A soft chord mixed into one mono WAV (notes = C4-relative pcs).
  List<double> _chordWav(List<int> pcs, double durSec, double decay) {
    const sr = 44100;
    final n = (sr * durSec).round();
    final out = List<double>.filled(n, 0);
    for (final pc in pcs) {
      final tone = _toneWav(_freq(60 + pc), durSec, const [1.0, 0.5, 0.28, 0.12],
          gain: 0.16, decay: decay);
      for (var i = 0; i < n; i++) {
        out[i] += tone[i];
      }
    }
    return out;
  }

  List<double> _toneWav(double freq, double durSec, List<double> partials,
      {double gain = 0.3, double decay = 2.0, double attack = 0.008}) {
    const sr = 44100;
    final n = (sr * durSec).round();
    final out = List<double>.filled(n, 0);
    var norm = 0.0;
    for (final p in partials) {
      norm += p;
    }
    for (var i = 0; i < n; i++) {
      final t = i / sr;
      var v = 0.0;
      for (var h = 0; h < partials.length; h++) {
        v += partials[h] * math.sin(2 * math.pi * freq * (h + 1) * t);
      }
      v /= norm;
      final env = t < attack ? t / attack : math.exp(-(t - attack) * decay);
      out[i] = v * env * gain;
    }
    return out;
  }

  List<double> _kickWav() {
    const sr = 44100;
    final n = (sr * 0.28).round();
    final out = List<double>.filled(n, 0);
    for (var i = 0; i < n; i++) {
      final t = i / sr;
      final phase = 2 * math.pi * (50 * t + (80 / 30) * (1 - math.exp(-t * 30)));
      out[i] = math.sin(phase) * math.exp(-t * 12) * 0.8;
    }
    return out;
  }

  List<double> _snareWav() {
    const sr = 44100;
    final n = (sr * 0.18).round();
    final rng = math.Random(1);
    final out = List<double>.filled(n, 0);
    for (var i = 0; i < n; i++) {
      final t = i / sr;
      final noise = rng.nextDouble() * 2 - 1;
      final tone = math.sin(2 * math.pi * 180 * t) * 0.3;
      out[i] = (noise * 0.7 + tone) * math.exp(-t * 22) * 0.5;
    }
    return out;
  }

  /// Plain decaying white noise — closed/open hats and the crash wash.
  List<double> _noiseWav(double durSec, double decay, double gain) {
    const sr = 44100;
    final n = (sr * durSec).round();
    final rng = math.Random(2);
    final out = List<double>.filled(n, 0);
    for (var i = 0; i < n; i++) {
      final t = i / sr;
      out[i] = (rng.nextDouble() * 2 - 1) * math.exp(-t * decay) * gain;
    }
    return out;
  }

  /// Ride — a short noise wash plus a metallic ping on top.
  List<double> _rideWav() {
    const sr = 44100;
    final n = (sr * 0.4).round();
    final rng = math.Random(3);
    final out = List<double>.filled(n, 0);
    for (var i = 0; i < n; i++) {
      final t = i / sr;
      final noise = (rng.nextDouble() * 2 - 1) * math.exp(-t * 9) * 0.2;
      final ping = math.sin(2 * math.pi * 5200 * t) * math.exp(-t * 14) * 0.1;
      out[i] = noise + ping;
    }
    return out;
  }

  /// Rim / sidestick — a woody click: short tone burst plus a snap of noise.
  List<double> _rimWav() {
    const sr = 44100;
    final n = (sr * 0.05).round();
    final rng = math.Random(4);
    final out = List<double>.filled(n, 0);
    for (var i = 0; i < n; i++) {
      final t = i / sr;
      final tone = math.sin(2 * math.pi * 1700 * t) * math.exp(-t * 80) * 0.4;
      final snap = (rng.nextDouble() * 2 - 1) * math.exp(-t * 90) * 0.18;
      out[i] = tone + snap;
    }
    return out;
  }

  /// Tom — a kick-style pitch sweep settling on the drum's fundamental.
  List<double> _tomWav(double f0) {
    const sr = 44100;
    final n = (sr * 0.3).round();
    final out = List<double>.filled(n, 0);
    for (var i = 0; i < n; i++) {
      final t = i / sr;
      final phase = 2 * math.pi * (f0 * t + (f0 * 0.6 / 25) * (1 - math.exp(-t * 25)));
      out[i] = math.sin(phase) * math.exp(-t * 9) * 0.6;
    }
    return out;
  }

  /// Count-in click — same voice as the metronome.
  List<double> _clickWav(double freq) {
    const sr = 44100;
    final n = (sr * 0.055).round();
    final out = List<double>.filled(n, 0);
    for (var i = 0; i < n; i++) {
      final t = i / sr;
      out[i] = math.sin(2 * math.pi * freq * t) * math.exp(-t * 70) * 0.6;
    }
    return out;
  }

  Uint8List _wav(List<double> mono) {
    const sr = 44100;
    final n = mono.length;
    final dataLen = n * 2;
    final b = ByteData(44 + dataLen);
    void str(int o, String s) {
      for (var i = 0; i < s.length; i++) {
        b.setUint8(o + i, s.codeUnitAt(i));
      }
    }

    str(0, 'RIFF');
    b.setUint32(4, 36 + dataLen, Endian.little);
    str(8, 'WAVE');
    str(12, 'fmt ');
    b.setUint32(16, 16, Endian.little);
    b.setUint16(20, 1, Endian.little);
    b.setUint16(22, 1, Endian.little);
    b.setUint32(24, sr, Endian.little);
    b.setUint32(28, sr * 2, Endian.little);
    b.setUint16(32, 2, Endian.little);
    b.setUint16(34, 16, Endian.little);
    str(36, 'data');
    b.setUint32(40, dataLen, Endian.little);
    for (var i = 0; i < n; i++) {
      b.setInt16(44 + i * 2, (mono[i].clamp(-1.0, 1.0) * 32767).round(), Endian.little);
    }
    return b.buffer.asUint8List();
  }
}
