import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:soundpool/soundpool.dart';

/// Metronome audio engine (Flutter port of the web lib/use-metronome.ts).
///
/// There's no Web Audio API on Flutter, so we play a short click sample through
/// soundpool and drive timing from a self-correcting loop: a fast timer checks
/// a monotonic [Stopwatch] and fires each beat as its absolute time arrives, so
/// tempo never drifts (the accumulator is the clock, not the timer interval).
/// Latency isn't sample-accurate like the web — fine for practice, not studio.
class MetronomeEngine {
  Soundpool? _pool;
  int? _clickId;
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
    if (_clickId != null || _loading) return;
    _loading = true;
    final pool = Soundpool.fromOptions(options: const SoundpoolOptions());
    _clickId = await pool.loadUint8List(_clickWav());
    _pool = pool;
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
      final pool = _pool;
      final id = _clickId;
      if (pool != null && id != null) {
        // Accent the downbeat by pitching the same click up a fifth.
        pool.play(id, rate: accent ? 1.5 : 1.0);
      }
      onBeat?.call(_beat);
      _beat = (_beat + 1) % beatsPerBar;
      _nextBeat += beatMs;
    }
  }

  void dispose() {
    _timer?.cancel();
    _pool?.dispose();
  }

  /// A short 1 kHz sine click with a fast exponential decay, as 16-bit mono PCM
  /// wrapped in a WAV container — generated so we don't ship an audio asset.
  Uint8List _clickWav() {
    const sampleRate = 44100;
    const freq = 1000.0;
    const durMs = 55;
    final n = (sampleRate * durMs / 1000).round();
    final dataLen = n * 2; // 16-bit mono
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
    bytes.setUint32(16, 16, Endian.little); // subchunk1 size
    bytes.setUint16(20, 1, Endian.little); // PCM
    bytes.setUint16(22, 1, Endian.little); // mono
    bytes.setUint32(24, sampleRate, Endian.little);
    bytes.setUint32(28, sampleRate * 2, Endian.little); // byte rate
    bytes.setUint16(32, 2, Endian.little); // block align
    bytes.setUint16(34, 16, Endian.little); // bits per sample
    writeStr(36, 'data');
    bytes.setUint32(40, dataLen, Endian.little);

    for (var i = 0; i < n; i++) {
      final t = i / sampleRate;
      final env = math.exp(-t * 70); // sharp click, quick decay
      final v = math.sin(2 * math.pi * freq * t) * env * 0.85;
      final s = (v * 32767).round().clamp(-32768, 32767);
      bytes.setInt16(44 + i * 2, s, Endian.little);
    }
    return bytes.buffer.asUint8List();
  }
}
