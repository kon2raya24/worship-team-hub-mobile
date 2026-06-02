import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

/// Backing-track engine (a SIMPLIFIED Flutter port of the web backing track).
///
/// The web version uses smplr soundfonts + sampled kits, which have no Flutter
/// equivalent (and soundpool — the obvious sample player — won't compile on the
/// current toolchain). So we synthesise everything in-Dart as WAV bytes and play
/// it through audioplayers in low-latency mode. To avoid fragile per-note
/// pitching/polyphony, each DISTINCT chord is pre-mixed into one triad WAV and
/// each distinct bass root into one WAV, each on its own preloaded player;
/// kick/snare/hat get one player each. A drift-free lookahead loop (like the
/// metronome) steps at the eighth note.
class BackingTrackEngine {
  final Map<String, AudioPlayer> _padFor = {}; // key: pcs joined
  final Map<int, AudioPlayer> _bassFor = {}; // key: root pc
  AudioPlayer? _kickP;
  AudioPlayer? _snareP;
  AudioPlayer? _hatP;
  List<List<int>> _builtFor = [];
  bool _building = false;

  Timer? _timer;
  final Stopwatch _clock = Stopwatch();
  double _nextStep = 0;
  int _stepInChord = 0;
  int _chordIndex = 0;

  // Live params.
  List<List<int>> chords = []; // each = absolute triad pitch classes [root,3rd,5th]
  int bpm = 90;
  int barsPerChord = 1;
  bool padOn = true;
  bool bassOn = true;
  bool drumsOn = true;

  void Function(int chordIndex)? onChord;

  static const _kickSteps = {0, 4};
  static const _snareSteps = {2, 6};

  bool get running => _timer != null;

  AudioPlayer _newPlayer() => AudioPlayer()
    ..setReleaseMode(ReleaseMode.stop)
    ..setPlayerMode(PlayerMode.lowLatency);

  Future<void> _ensureBuilt() async {
    if (_building) return;
    if (_listEq(_builtFor, chords) && _padFor.isNotEmpty) return;
    _building = true;

    // Drums are chord-independent — build once.
    if (_kickP == null) {
      _kickP = _newPlayer();
      _snareP = _newPlayer();
      _hatP = _newPlayer();
      await _kickP!.setSourceBytes(_wav(_kickWav()), mimeType: 'audio/wav');
      await _snareP!.setSourceBytes(_wav(_snareWav()), mimeType: 'audio/wav');
      await _hatP!.setSourceBytes(_wav(_hatWav()), mimeType: 'audio/wav');
    }

    // Rebuild the per-chord pad + bass players for the current progression.
    for (final p in _padFor.values) {
      p.dispose();
    }
    for (final p in _bassFor.values) {
      p.dispose();
    }
    _padFor.clear();
    _bassFor.clear();

    for (final chord in chords) {
      final key = chord.join(',');
      if (!_padFor.containsKey(key)) {
        final pp = _newPlayer();
        await pp.setSourceBytes(_wav(_chordWav(chord)), mimeType: 'audio/wav');
        _padFor[key] = pp;
      }
      final root = chord[0];
      if (!_bassFor.containsKey(root)) {
        final bp = _newPlayer();
        await bp.setSourceBytes(_wav(_toneWav(_freq(36 + root), 1.0, const [1.0, 0.45, 0.15], gain: 0.5, decay: 3.0)), mimeType: 'audio/wav');
        _bassFor[root] = bp;
      }
    }
    _builtFor = [for (final c in chords) List<int>.of(c)];
    _building = false;
  }

  Future<void> start() async {
    if (running) return;
    if (chords.isEmpty) return;
    await _ensureBuilt();
    _stepInChord = 0;
    _chordIndex = 0;
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
    final stepsPerChord = barsPerChord * 8;
    final eighth = _stepInChord % 8;
    final chord = chords[_chordIndex % chords.length];

    if (_stepInChord == 0) onChord?.call(_chordIndex % chords.length);

    if (eighth == 0) {
      if (padOn) _padFor[chord.join(',')]?.resume();
      if (bassOn) _bassFor[chord[0]]?.resume();
    }
    if (drumsOn) {
      if (_kickSteps.contains(eighth)) _kickP?.resume();
      if (_snareSteps.contains(eighth)) _snareP?.resume();
      _hatP?.resume();
    }

    _stepInChord++;
    if (_stepInChord >= stepsPerChord) {
      _stepInChord = 0;
      _chordIndex = (_chordIndex + 1) % chords.length;
    }
  }

  void dispose() {
    _timer?.cancel();
    for (final p in _padFor.values) {
      p.dispose();
    }
    for (final p in _bassFor.values) {
      p.dispose();
    }
    _kickP?.dispose();
    _snareP?.dispose();
    _hatP?.dispose();
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

  /// A soft triad mixed into one mono WAV (pad notes = C4-relative pcs).
  List<double> _chordWav(List<int> pcs) {
    const sr = 44100;
    const durSec = 1.4;
    final n = (sr * durSec).round();
    final out = List<double>.filled(n, 0);
    for (final pc in pcs) {
      final tone = _toneWav(_freq(60 + pc), durSec, const [1.0, 0.5, 0.28, 0.12], gain: 0.18, decay: 1.6);
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

  List<double> _hatWav() {
    const sr = 44100;
    final n = (sr * 0.05).round();
    final rng = math.Random(2);
    final out = List<double>.filled(n, 0);
    for (var i = 0; i < n; i++) {
      final t = i / sr;
      out[i] = (rng.nextDouble() * 2 - 1) * math.exp(-t * 60) * 0.32;
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
