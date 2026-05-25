import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/theme.dart';
import '../../../data/sync/providers.dart';
import '../chordpro/chordpro.dart';
import 'chord_viewer.dart';

class SongDetailScreen extends ConsumerWidget {
  const SongDetailScreen({super.key, required this.songId, this.targetKey});

  final String songId;

  /// Optional target key (e.g. from a setlist's "played_in_key") — when set,
  /// the chord chart opens already transposed from the song's original key
  /// to this key.
  final String? targetKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final song = ref.watch(songByIdProvider(songId));
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 20),
          onPressed: () => context.canPop() ? context.pop() : context.go('/songs'),
        ),
        title: const Text('Chord chart'),
      ),
      body: song.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            'Failed to load song.\n$e',
            style: const TextStyle(color: Sanctuary.muted),
          ),
        ),
        data: (s) {
          if (s == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Song not found in local cache.\nPull to sync from the home screen.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Sanctuary.muted),
                ),
              ),
            );
          }
          return _SongBody(
            title: s.title,
            artist: s.artist,
            originalKey: s.originalKey,
            chordproBody: s.chordproBody,
            initialTranspose:
                ChordPro.semitonesBetween(s.originalKey, targetKey),
          );
        },
      ),
    );
  }
}

class _SongBody extends StatefulWidget {
  const _SongBody({
    required this.title,
    required this.artist,
    required this.originalKey,
    required this.chordproBody,
    this.initialTranspose = 0,
  });

  final String title;
  final String? artist;
  final String? originalKey;
  final String chordproBody;
  final int initialTranspose;

  @override
  State<_SongBody> createState() => _SongBodyState();
}

class _SongBodyState extends State<_SongBody> {
  late int _transpose = widget.initialTranspose;
  double _fontSize = 14;
  final ScrollController _scroll = ScrollController();
  Timer? _autoScrollTimer;
  bool _autoScrolling = false;
  // Pixels per tick at ~60Hz. 0.4 ≈ slow read; 1.6 ≈ fast playback.
  double _scrollSpeed = 0.6;

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _toggleAutoScroll() {
    if (_autoScrolling) {
      _autoScrollTimer?.cancel();
      _autoScrollTimer = null;
      // ignore: discarded_futures
      WakelockPlus.disable();
      setState(() => _autoScrolling = false);
      return;
    }
    setState(() => _autoScrolling = true);
    // ignore: discarded_futures
    WakelockPlus.enable();
    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!_scroll.hasClients) return;
      final max = _scroll.position.maxScrollExtent;
      final next = _scroll.position.pixels + _scrollSpeed;
      if (next >= max) {
        _scroll.jumpTo(max);
        _toggleAutoScroll();
      } else {
        _scroll.jumpTo(next);
      }
    });
  }

  void _setSpeed(double v) {
    setState(() => _scrollSpeed = v.clamp(0.15, 2.4));
  }

  @override
  Widget build(BuildContext context) {
    final body = widget.chordproBody.trim();
    final parsed = body.isEmpty
        ? null
        : ChordPro.transpose(ChordPro.parse(body), _transpose);
    final currentKey = parsed?.key ?? widget.originalKey;

    return Stack(
      children: [
        ListView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            Text(widget.title, style: Sanctuary.display(fontSize: 26)),
            if ((widget.artist ?? '').isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                widget.artist!,
                style: const TextStyle(color: Sanctuary.muted, fontSize: 14),
              ),
            ],
            const SizedBox(height: 16),
            _Controls(
              currentKey: currentKey,
              transpose: _transpose,
              autoScrolling: _autoScrolling,
              onTransposeDown: () => setState(() => _transpose -= 1),
              onTransposeUp: () => setState(() => _transpose += 1),
              onTransposeReset: () => setState(() => _transpose = 0),
              onFontDown: () => setState(
                () => _fontSize = (_fontSize - 1).clamp(11, 22),
              ),
              onFontUp: () => setState(
                () => _fontSize = (_fontSize + 1).clamp(11, 22),
              ),
              onToggleAutoScroll: _toggleAutoScroll,
            ),
            const SizedBox(height: 16),
            GlassCard(
              padding: const EdgeInsets.all(18),
              child: parsed == null
                  ? const Text(
                      'No chord chart yet.',
                      style: TextStyle(color: Sanctuary.muted),
                    )
                  : ChordViewer(song: parsed, fontSize: _fontSize),
            ),
          ],
        ),
        if (_autoScrolling)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: _SpeedBar(
              speed: _scrollSpeed,
              onChanged: _setSpeed,
              onStop: _toggleAutoScroll,
            ),
          ),
      ],
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.currentKey,
    required this.transpose,
    required this.autoScrolling,
    required this.onTransposeDown,
    required this.onTransposeUp,
    required this.onTransposeReset,
    required this.onFontDown,
    required this.onFontUp,
    required this.onToggleAutoScroll,
  });

  final String? currentKey;
  final int transpose;
  final bool autoScrolling;
  final VoidCallback onTransposeDown;
  final VoidCallback onTransposeUp;
  final VoidCallback onTransposeReset;
  final VoidCallback onFontDown;
  final VoidCallback onFontUp;
  final VoidCallback onToggleAutoScroll;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          if ((currentKey ?? '').isNotEmpty) ...[
            _Pill(
              label: 'KEY',
              value: currentKey!,
              accent: Sanctuary.auroraViolet,
            ),
            const SizedBox(width: 10),
          ],
          if (transpose != 0)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: GestureDetector(
                onTap: onTransposeReset,
                child: Text(
                  transpose > 0 ? '+$transpose' : '$transpose',
                  style: Sanctuary.mono(
                    fontSize: 12,
                    color: Sanctuary.auroraAmber,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ),
          const Spacer(),
          _IconBtn(
            icon: autoScrolling ? Icons.pause : Icons.play_arrow,
            onTap: onToggleAutoScroll,
            highlighted: autoScrolling,
          ),
          const SizedBox(width: 12),
          _IconBtn(icon: Icons.text_decrease, onTap: onFontDown),
          const SizedBox(width: 4),
          _IconBtn(icon: Icons.text_increase, onTap: onFontUp),
          const SizedBox(width: 12),
          _IconBtn(icon: Icons.remove, onTap: onTransposeDown),
          const SizedBox(width: 4),
          _IconBtn(icon: Icons.add, onTap: onTransposeUp),
        ],
      ),
    );
  }
}

class _SpeedBar extends StatelessWidget {
  const _SpeedBar({
    required this.speed,
    required this.onChanged,
    required this.onStop,
  });

  final double speed;
  final ValueChanged<double> onChanged;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.speed, size: 18, color: Sanctuary.auroraCyan),
          const SizedBox(width: 8),
          Text(
            speed.toStringAsFixed(1),
            style: Sanctuary.mono(
              fontSize: 12,
              color: Sanctuary.auroraCyan,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: Sanctuary.auroraCyan,
                inactiveTrackColor: Sanctuary.hairline,
                thumbColor: Sanctuary.auroraCyan,
                overlayColor: Sanctuary.auroraCyan.withValues(alpha: 0.2),
                trackHeight: 2,
              ),
              child: Slider(
                value: speed,
                min: 0.15,
                max: 2.4,
                onChanged: onChanged,
              ),
            ),
          ),
          _IconBtn(icon: Icons.stop, onTap: onStop, highlighted: true),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.value,
    required this.accent,
  });
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(Sanctuary.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Sanctuary.mono(fontSize: 10, color: accent)),
          const SizedBox(width: 6),
          Text(
            value,
            style: Sanctuary.mono(
              fontSize: 13,
              color: accent,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({
    required this.icon,
    required this.onTap,
    this.highlighted = false,
  });
  final IconData icon;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final accent = highlighted ? Sanctuary.auroraCyan : null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(Sanctuary.radiusSm),
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: accent?.withValues(alpha: 0.15) ?? Sanctuary.glass1,
            border: Border.all(
              color: accent?.withValues(alpha: 0.4) ?? Sanctuary.hairline,
            ),
            borderRadius: BorderRadius.circular(Sanctuary.radiusSm),
          ),
          child: Icon(icon, size: 16, color: accent ?? Sanctuary.foreground),
        ),
      ),
    );
  }
}

