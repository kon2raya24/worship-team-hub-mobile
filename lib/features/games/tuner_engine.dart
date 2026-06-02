import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';

/// Chromatic tuner engine (Flutter port of the web lib/use-tuner.ts).
///
/// flutter_sound gives us a PCM16 microphone stream; pitch detection is done
/// here in Dart with the same autocorrelation (ACF2+ + parabolic interpolation)
/// the web uses. The O(n²) correlation is throttled to ~10/sec so it doesn't
/// jank the UI thread (a future optimisation could move it to an isolate).

const List<String> _noteNames = [
  'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B',
];
const int _frame = 2048;
const double _rmsFloor = 0.01;

class TunerReading {
  final String note;
  final int octave;
  final int cents; // signed offset from the nearest note, ~-50..+50
  final double frequency;
  const TunerReading(this.note, this.octave, this.cents, this.frequency);
}

class TunerEngine {
  final FlutterSoundRecorder _rec = FlutterSoundRecorder();
  StreamController<Uint8List>? _controller;
  StreamSubscription<Uint8List>? _sub;
  bool _opened = false;
  final List<double> _buf = [];
  final int _sampleRate = 44100;

  double a4 = 440;
  bool listening = false;

  void Function(TunerReading? reading)? onReading;
  void Function(String message)? onError;

  int? _lastMidi;
  double _smoothCents = 0;
  int _lastProcessMs = 0;
  int _silentFrames = 0;

  Future<bool> start() async {
    if (listening) return true;
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      onError?.call('Microphone access was blocked — allow it, then start again.');
      return false;
    }
    if (!_opened) {
      await _rec.openRecorder();
      _opened = true;
    }
    _controller = StreamController<Uint8List>();
    _sub = _controller!.stream.listen(_onChunk, onError: (_) {});
    listening = true;
    _silentFrames = 0;
    // Disable echo/noise DSP — it warps the signal and throws off detection.
    await _rec.startRecorder(
      codec: Codec.pcm16,
      toStream: _controller!.sink,
      sampleRate: _sampleRate,
      numChannels: 1,
      enableEchoCancellation: false,
      enableNoiseSuppression: false,
    );
    return true;
  }

  Future<void> stop() async {
    listening = false;
    if (_rec.isRecording) await _rec.stopRecorder();
    await _sub?.cancel();
    _sub = null;
    await _controller?.close();
    _controller = null;
    _buf.clear();
    _lastMidi = null;
    onReading?.call(null);
  }

  void dispose() {
    _sub?.cancel();
    _controller?.close();
    if (_opened) _rec.closeRecorder();
  }

  void _onChunk(Uint8List bytes) {
    final bd = ByteData.sublistView(bytes);
    for (var i = 0; i + 1 < bytes.length; i += 2) {
      _buf.add(bd.getInt16(i, Endian.little) / 32768.0);
    }
    if (_buf.length > _frame * 4) {
      _buf.removeRange(0, _buf.length - _frame * 2);
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_buf.length < _frame || now - _lastProcessMs < 90) {
      return;
    }
    _lastProcessMs = now;
    final frame = _buf.sublist(_buf.length - _frame);
    _emit(_autoCorrelate(frame, _sampleRate.toDouble()));
  }

  void _emit(double freq) {
    if (freq <= 0) {
      _silentFrames++;
      if (_silentFrames >= 5) {
        _lastMidi = null;
        onReading?.call(null);
      }
      return;
    }
    _silentFrames = 0;
    final midi = (12 * _log2(freq / a4) + 69).round();
    final refFreq = a4 * math.pow(2, (midi - 69) / 12);
    final rawCents = 1200 * _log2(freq / refFreq);
    if (midi == _lastMidi) {
      _smoothCents = _smoothCents * 0.7 + rawCents * 0.3;
    } else {
      _smoothCents = rawCents;
      _lastMidi = midi;
    }
    onReading?.call(TunerReading(
      _noteNames[((midi % 12) + 12) % 12],
      (midi ~/ 12) - 1,
      _smoothCents.round(),
      (freq * 10).round() / 10,
    ));
  }

  double _log2(double x) => math.log(x) / math.ln2;

  /// Returns the detected fundamental in Hz, or -1 when there's no clear pitch.
  double _autoCorrelate(List<double> buf, double sampleRate) {
    final size = buf.length;
    var rms = 0.0;
    for (var i = 0; i < size; i++) {
      rms += buf[i] * buf[i];
    }
    rms = math.sqrt(rms / size);
    if (rms < _rmsFloor) {
      return -1;
    }

    var r1 = 0;
    var r2 = size - 1;
    const thres = 0.2;
    for (var i = 0; i < size ~/ 2; i++) {
      if (buf[i].abs() < thres) {
        r1 = i;
        break;
      }
    }
    for (var i = 1; i < size ~/ 2; i++) {
      if (buf[size - i].abs() < thres) {
        r2 = size - i;
        break;
      }
    }

    final trimmed = buf.sublist(r1, r2);
    final n = trimmed.length;
    if (n < 2) {
      return -1;
    }

    final c = List<double>.filled(n, 0);
    for (var i = 0; i < n; i++) {
      var sum = 0.0;
      for (var j = 0; j < n - i; j++) {
        sum += trimmed[j] * trimmed[j + i];
      }
      c[i] = sum;
    }

    var d = 0;
    while (d < n - 1 && c[d] > c[d + 1]) {
      d++;
    }
    var maxval = -1.0;
    var maxpos = -1;
    for (var i = d; i < n; i++) {
      if (c[i] > maxval) {
        maxval = c[i];
        maxpos = i;
      }
    }
    if (maxpos <= 0) {
      return -1;
    }

    var t0 = maxpos.toDouble();
    if (maxpos > 0 && maxpos < n - 1) {
      final x1 = c[maxpos - 1];
      final x2 = c[maxpos];
      final x3 = c[maxpos + 1];
      final a = (x1 + x3 - 2 * x2) / 2;
      final b = (x3 - x1) / 2;
      if (a != 0) {
        t0 = maxpos - b / (2 * a);
      }
    }
    return t0 > 0 ? sampleRate / t0 : -1;
  }
}
