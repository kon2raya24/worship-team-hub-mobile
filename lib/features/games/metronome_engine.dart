import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_soloud/flutter_soloud.dart';

/// Metronome audio engine (Flutter port of the web lib/use-metronome.ts).
///
/// Uses flutter_soloud — a low-latency in-memory engine — with two preloaded
/// clicks (a normal one and a higher accent for the downbeat), synthesised in
/// Dart as WAV bytes. Timing comes from a self-correcting loop: a fast timer
/// checks a monotonic [Stopwatch] and fires each beat at its absolute time, so
/// tempo doesn't drift. soloud is polyphonic, so clicks never cut each other.
class MetronomeEngine {
  AudioSource? _normal;
  AudioSource? _accent;
  bool _loading = false;

  Timer? _timer;
  final Stopwatch _clock = Stopwatch();
  double _nextBeat = 0; // ms on the stopwatch clock
  int _beat = 0;

  int bpm = 100;
  int beatsPerBar = 4;

  /// Called with the current beat index (0-based) on each click, and -1 on stop.
  void Function(int beat)? onBeat;

  bool get running => _timer != null;

  void setBeatsPerBar(int n) {
    beatsPerBar = n;
    if (_beat >= n) _beat = 0;
  }

  Future<void> _ensureLoaded() async {
    if (_normal != null || _loading) return;
    _loading = true;
    final s = SoLoud.instance;
    if (!s.isInitialized) await s.init();
    _normal = await s.loadMem('metro-normal.wav', _clickWav(1000));
    _accent = await s.loadMem('metro-accent.wav', _clickWav(1500));
    _loading = false;
  }

  Future<void> start() async {
    if (running) return;
    await _ensureLoaded();
    _beat = 0;
    _clock
      ..reset()
      ..start();
    _nextBeat = 0;
    _timer = Timer.periodic(const Duration(milliseconds: 8), (_) => _tick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _clock.stop();
    onBeat?.call(-1);
  }

  void toggle() => running ? stop() : start();

  void _tick() {
    final beatMs = 60000 / bpm;
    final now = _clock.elapsedMilliseconds.toDouble();
    // Fire every beat whose scheduled time has passed (catches up after a stall).
    while (now >= _nextBeat) {
      final accent = _beat == 0;
      final src = accent ? _accent : _normal;
      if (src != null) SoLoud.instance.play(src);
      onBeat?.call(_beat);
      _beat = (_beat + 1) % beatsPerBar;
      _nextBeat += beatMs;
    }
  }

  void dispose() {
    _timer?.cancel();
    final s = SoLoud.instance;
    final n = _normal;
    final a = _accent;
    if (n != null) s.disposeSource(n);
    if (a != null) s.disposeSource(a);
    _normal = null;
    _accent = null;
  }

  /// A short sine click with a fast exponential decay, as 16-bit mono PCM in a
  /// WAV container — generated so we don't ship an audio asset.
  Uint8List _clickWav(double freq) {
    const sampleRate = 44100;
    const durMs = 55;
    final n = (sampleRate * durMs / 1000).round();
    final dataLen = n * 2;
    final bytes = ByteData(44 + dataLen);

    void writeStr(int offset, String s) {
      for (var i = 0; i < s.length; i++) {
        bytes.setUint8(offset + i, s.codeUnitAt(i));
      }
    }

    writeStr(0, 'RIFF');
    bytes.setUint32(4, 36 + dataLen, Endian.little);
    writeStr(8, 'WAVE');
    writeStr(12, 'fmt ');
    bytes.setUint32(16, 16, Endian.little);
    bytes.setUint16(20, 1, Endian.little);
    bytes.setUint16(22, 1, Endian.little);
    bytes.setUint32(24, sampleRate, Endian.little);
    bytes.setUint32(28, sampleRate * 2, Endian.little);
    bytes.setUint16(32, 2, Endian.little);
    bytes.setUint16(34, 16, Endian.little);
    writeStr(36, 'data');
    bytes.setUint32(40, dataLen, Endian.little);

    for (var i = 0; i < n; i++) {
      final t = i / sampleRate;
      final env = math.exp(-t * 70);
      final v = math.sin(2 * math.pi * freq * t) * env * 0.85;
      bytes.setInt16(44 + i * 2, (v * 32767).round().clamp(-32768, 32767), Endian.little);
    }
    return bytes.buffer.asUint8List();
  }
}
