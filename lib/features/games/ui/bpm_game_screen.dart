import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';

const _windowSize = 8;
const _resetAfterMs = 2200;

class BpmGameScreen extends StatefulWidget {
  const BpmGameScreen({super.key});

  @override
  State<BpmGameScreen> createState() => _BpmGameScreenState();
}

class _BpmGameScreenState extends State<BpmGameScreen> {
  int _target = 90;
  int _bpm = 0;
  int _taps = 0;
  DateTime? _lastTap;
  final List<int> _intervals = [];
  bool _flash = false;
  Timer? _flashTimer;

  static const _presets = [
    ('Ballad', 72),
    ('Mid', 90),
    ('Upbeat', 120),
    ('Fast', 140),
  ];

  @override
  void dispose() {
    _flashTimer?.cancel();
    super.dispose();
  }

  void _tap() {
    final now = DateTime.now();
    _flashTimer?.cancel();
    setState(() => _flash = true);
    _flashTimer = Timer(const Duration(milliseconds: 90), () {
      if (mounted) setState(() => _flash = false);
    });

    if (_lastTap == null) {
      setState(() {
        _lastTap = now;
        _taps = 1;
        _bpm = 0;
      });
      return;
    }
    final dt = now.difference(_lastTap!).inMilliseconds;
    _lastTap = now;
    if (dt > _resetAfterMs) {
      _intervals.clear();
      setState(() {
        _taps = 1;
        _bpm = 0;
      });
      return;
    }
    _intervals.add(dt);
    if (_intervals.length > _windowSize) {
      _intervals.removeAt(0);
    }
    final avg = _intervals.reduce((a, b) => a + b) / _intervals.length;
    setState(() {
      _taps++;
      _bpm = (60000 / avg).round();
    });
  }

  void _reset() {
    setState(() {
      _bpm = 0;
      _taps = 0;
      _lastTap = null;
      _intervals.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final successColor = isDark ? Sanctuary.success : Sanctuary.lightSuccess;
    final diff = _bpm > 0 ? _bpm - _target : 0;
    final within = diff.abs() <= 2 && _bpm > 0;
    final close = !within && diff.abs() <= 5 && _bpm > 0;
    Color colour = cs.onSurfaceVariant;
    String hint = 'Tap to start';
    if (_bpm > 0) {
      if (within) {
        colour = successColor;
        hint = 'On the beat';
      } else if (close) {
        colour = Sanctuary.auroraAmber;
        hint = 'Drifting';
      } else {
        colour = cs.error;
        hint = diff > 0 ? 'Rushing' : 'Dragging';
      }
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 20),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/games'),
        ),
        title: const Text('BPM Tapper'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TARGET BPM',
                    style: Sanctuary.mono(
                        fontSize: 10, color: cs.onSurfaceVariant)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _presets.map((p) {
                    final selected = _target == p.$2;
                    return InkWell(
                      onTap: () => setState(() => _target = p.$2),
                      borderRadius: BorderRadius.circular(Sanctuary.radiusMd),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected
                              ? cs.secondary.withValues(alpha: 0.15)
                              : (isDark
                                  ? Sanctuary.glass1
                                  : Sanctuary.lightGlass1),
                          border: Border.all(
                              color: selected
                                  ? cs.secondary.withValues(alpha: 0.5)
                                  : cs.outlineVariant),
                          borderRadius:
                              BorderRadius.circular(Sanctuary.radiusMd),
                        ),
                        child: Text(
                          '${p.$1} ${p.$2}',
                          style: Sanctuary.mono(
                              fontSize: 11,
                              color: selected
                                  ? cs.secondary
                                  : cs.onSurfaceVariant),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: TextField(
                        keyboardType: TextInputType.number,
                        controller: TextEditingController(text: '$_target'),
                        decoration: const InputDecoration(isDense: true),
                        style: Sanctuary.mono(
                          fontSize: 14,
                          color: cs.onSurface,
                          letterSpacing: 0,
                        ),
                        onSubmitted: (v) {
                          final n = int.tryParse(v);
                          if (n != null && n >= 30 && n <= 240) {
                            setState(() => _target = n);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('custom',
                        style: Sanctuary.mono(
                            fontSize: 11, color: cs.onSurfaceVariant)),
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('YOUR TEMPO',
                            style: Sanctuary.mono(
                                fontSize: 10, color: cs.onSurfaceVariant)),
                        const SizedBox(height: 2),
                        Text(
                          _bpm > 0 ? '$_bpm' : '—',
                          style: Sanctuary.display(
                              fontSize: 56,
                              fontWeight: FontWeight.w600,
                              color: colour),
                        ),
                        Text('BPM',
                            style:
                                Sanctuary.mono(fontSize: 11, color: colour)),
                      ],
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('DELTA',
                            style: Sanctuary.mono(
                                fontSize: 10, color: cs.onSurfaceVariant)),
                        const SizedBox(height: 2),
                        Text(
                          _bpm > 0
                              ? (diff > 0 ? '+$diff' : '$diff')
                              : '—',
                          style: Sanctuary.display(
                              fontSize: 28,
                              fontWeight: FontWeight.w600,
                              color: colour),
                        ),
                        Text(hint,
                            style: Sanctuary.mono(
                                fontSize: 11, color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(Sanctuary.radiusLg),
                    onTap: _tap,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 80),
                      height: 140,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Sanctuary.auroraCyan.withValues(alpha: 0.18),
                            Sanctuary.auroraViolet.withValues(alpha: 0.22),
                            Sanctuary.auroraMagenta.withValues(alpha: 0.18),
                          ],
                        ),
                        border: Border.all(
                          color: _flash
                              ? Sanctuary.auroraCyan.withValues(alpha: 0.7)
                              : cs.outlineVariant,
                          width: _flash ? 2 : 1,
                        ),
                        borderRadius:
                            BorderRadius.circular(Sanctuary.radiusLg),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('TAP',
                              style: Sanctuary.display(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  color: cs.onSurface)),
                          const SizedBox(height: 4),
                          Text('$_taps tap${_taps == 1 ? "" : "s"}',
                              style: Sanctuary.mono(
                                  fontSize: 10, color: cs.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '~4 taps before the reading stabilises. Pause 2 sec to reset.',
                        style: TextStyle(
                            color: cs.onSurfaceVariant, fontSize: 11),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _reset,
                      icon: const Icon(Icons.refresh, size: 14),
                      label: const Text('Reset'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
