import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/env.dart';
import '../../../core/theme.dart';
import '../../../data/sync/providers.dart';
import '../../../data/sync/sync_service.dart';
import '../../auth/auth_provider.dart';
import '../chordpro/chordpro.dart';
import 'chord_viewer.dart';
import 'song_notes_section.dart';

class SongDetailScreen extends ConsumerWidget {
  const SongDetailScreen({super.key, required this.songId, this.targetKey});

  final String songId;

  /// Optional target key (e.g. from a setlist's "played_in_key") — when set,
  /// the chord chart opens already transposed from the song's original key
  /// to this key.
  final String? targetKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final song = ref.watch(songByIdProvider(songId));
    final isLeader = ref.watch(isLeaderProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 20),
          onPressed: () => context.canPop() ? context.pop() : context.go('/songs'),
        ),
        title: const Text('Chord chart'),
        actions: [
          if (isLeader)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20),
              color: cs.surfaceContainer,
              onSelected: (v) async {
                if (v == 'edit') {
                  context.push('/songs/$songId/edit');
                } else if (v == 'share') {
                  final token = await ref
                      .read(syncServiceProvider)
                      .createShareLink(
                          resourceType: 'song', resourceId: songId);
                  if (!context.mounted) return;
                  if (token != null) {
                    await Share.share('${Env.webBaseUrl}/share/$token');
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Could not create share link.')),
                    );
                  }
                } else if (v == 'delete') {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: cs.surfaceContainer,
                      title: const Text('Delete song?'),
                      content: const Text(
                        'This removes the song for everyone — including '
                        'any setlist references.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: cs.error,
                          ),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (ok != true) return;
                  final deleted = await ref
                      .read(syncServiceProvider)
                      .deleteSong(songId);
                  if (!context.mounted) return;
                  if (deleted) {
                    context.go('/songs');
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Delete failed.')),
                    );
                  }
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(children: [
                    Icon(Icons.edit_outlined),
                    SizedBox(width: 8),
                    Text('Edit'),
                  ]),
                ),
                const PopupMenuItem(
                  value: 'share',
                  child: Row(children: [
                    Icon(Icons.ios_share),
                    SizedBox(width: 8),
                    Text('Share link'),
                  ]),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    Icon(Icons.delete_outline, color: cs.error),
                    const SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: cs.error)),
                  ]),
                ),
              ],
            ),
        ],
      ),
      body: song.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            'Failed to load song.\n$e',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        ),
        data: (s) {
          if (s == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Song not found in local cache.\nPull to sync from the home screen.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ),
            );
          }
          return _SongBody(
            songId: s.id,
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
    required this.songId,
    required this.title,
    required this.artist,
    required this.originalKey,
    required this.chordproBody,
    this.initialTranspose = 0,
  });

  final String songId;
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
  int _capo = 0;
  double _fontSize = 14;
  final ScrollController _scroll = ScrollController();
  Timer? _autoScrollTimer;
  bool _autoScrolling = false;
  // Pixels per tick at ~60Hz. 0.4 ≈ slow read; 1.6 ≈ fast playback.
  double _scrollSpeed = 0.6;
  // Persisted prefs key prefix — one entry per song so each chart keeps
  // its own transpose / capo / font / speed across visits.
  String get _prefsKey => 'chord-viewer:${widget.songId}';
  bool _hydrated = false;

  @override
  void initState() {
    super.initState();
    _hydrate();
  }

  Future<void> _hydrate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) {
        if (mounted) setState(() => _hydrated = true);
        return;
      }
      // Stored as: "transpose,capo,fontSize,scrollSpeed"
      final parts = raw.split(',');
      if (parts.length >= 4 && mounted) {
        setState(() {
          _transpose = int.tryParse(parts[0]) ?? _transpose;
          _capo = int.tryParse(parts[1])?.clamp(0, 11) ?? 0;
          _fontSize =
              (double.tryParse(parts[2]) ?? _fontSize).clamp(11, 22).toDouble();
          _scrollSpeed = (double.tryParse(parts[3]) ?? _scrollSpeed)
              .clamp(0.15, 2.4)
              .toDouble();
          _hydrated = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _hydrated = true);
    }
  }

  Future<void> _persist() async {
    if (!_hydrated) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        '$_transpose,$_capo,$_fontSize,$_scrollSpeed',
      );
    } catch (_) {
      // Quota / permission errors are non-fatal — settings just won't carry
      // over to the next session.
    }
  }

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
    _persist();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final body = widget.chordproBody.trim();
    // Capo lowers the chord NAMES on the chart by the capo position so the
    // player can use the same shapes; effective render offset is
    // (transpose - capo). Matches the web ChordViewer.
    final renderOffset = _transpose - _capo;
    final parsed = body.isEmpty
        ? null
        : ChordPro.transpose(ChordPro.parse(body), renderOffset);
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
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
              ),
            ],
            const SizedBox(height: 16),
            _Controls(
              originalKey: widget.originalKey,
              currentKey: currentKey,
              transpose: _transpose,
              capo: _capo,
              autoScrolling: _autoScrolling,
              onTransposeDown: () {
                setState(() => _transpose -= 1);
                _persist();
              },
              onTransposeUp: () {
                setState(() => _transpose += 1);
                _persist();
              },
              onTransposeReset: () {
                setState(() => _transpose = 0);
                _persist();
              },
              onCapoDown: () {
                setState(() => _capo = (_capo - 1).clamp(0, 11));
                _persist();
              },
              onCapoUp: () {
                setState(() => _capo = (_capo + 1).clamp(0, 11));
                _persist();
              },
              onFontDown: () {
                setState(() => _fontSize = (_fontSize - 1).clamp(11, 22));
                _persist();
              },
              onFontUp: () {
                setState(() => _fontSize = (_fontSize + 1).clamp(11, 22));
                _persist();
              },
              onToggleAutoScroll: _toggleAutoScroll,
            ),
            const SizedBox(height: 16),
            GlassCard(
              padding: const EdgeInsets.all(18),
              child: parsed == null
                  ? Text(
                      'No chord chart yet.',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    )
                  : ChordViewer(song: parsed, fontSize: _fontSize),
            ),
            const SizedBox(height: 14),
            SongNotesSection(songId: widget.songId),
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
    required this.originalKey,
    required this.currentKey,
    required this.transpose,
    required this.capo,
    required this.autoScrolling,
    required this.onTransposeDown,
    required this.onTransposeUp,
    required this.onTransposeReset,
    required this.onCapoDown,
    required this.onCapoUp,
    required this.onFontDown,
    required this.onFontUp,
    required this.onToggleAutoScroll,
  });

  final String? originalKey;
  final String? currentKey;
  final int transpose;
  final int capo;
  final bool autoScrolling;
  final VoidCallback onTransposeDown;
  final VoidCallback onTransposeUp;
  final VoidCallback onTransposeReset;
  final VoidCallback onCapoDown;
  final VoidCallback onCapoUp;
  final VoidCallback onFontDown;
  final VoidCallback onFontUp;
  final VoidCallback onToggleAutoScroll;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        children: [
          Row(
            children: [
              if ((currentKey ?? '').isNotEmpty)
                Expanded(
                  child: GestureDetector(
                    onTap: transpose != 0 ? onTransposeReset : null,
                    child: _Pill(
                      label: 'KEY',
                      value: (transpose != 0 &&
                              (originalKey ?? '').isNotEmpty &&
                              originalKey != currentKey)
                          ? '${originalKey!} → ${currentKey!}'
                          : currentKey!,
                      accent: cs.primary,
                    ),
                  ),
                )
              else
                const Spacer(),
              const SizedBox(width: 8),
              _IconBtn(icon: Icons.remove, onTap: onTransposeDown),
              const SizedBox(width: 4),
              _IconBtn(icon: Icons.add, onTap: onTransposeUp),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _MiniPill(
                label: 'CAPO',
                value: '$capo',
                accent: cs.secondary,
              ),
              const SizedBox(width: 4),
              _IconBtn(icon: Icons.remove, onTap: onCapoDown),
              const SizedBox(width: 4),
              _IconBtn(icon: Icons.add, onTap: onCapoUp),
              const Spacer(),
              _IconBtn(icon: Icons.text_decrease, onTap: onFontDown),
              const SizedBox(width: 4),
              _IconBtn(icon: Icons.text_increase, onTap: onFontUp),
              const SizedBox(width: 8),
              _IconBtn(
                icon: autoScrolling ? Icons.pause : Icons.play_arrow,
                onTap: onToggleAutoScroll,
                highlighted: autoScrolling,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Tighter pill used inside the controls row alongside the transpose/capo
/// buttons. Same look as _Pill but smaller.
class _MiniPill extends StatelessWidget {
  const _MiniPill({
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(Sanctuary.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Sanctuary.mono(fontSize: 9, color: accent)),
          const SizedBox(width: 5),
          Text(
            value,
            style: Sanctuary.mono(
              fontSize: 12,
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
    final cs = Theme.of(context).colorScheme;
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.speed, size: 18, color: cs.secondary),
          const SizedBox(width: 8),
          Text(
            speed.toStringAsFixed(1),
            style: Sanctuary.mono(
              fontSize: 12,
              color: cs.secondary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: cs.secondary,
                inactiveTrackColor: cs.outlineVariant,
                thumbColor: cs.secondary,
                overlayColor: cs.secondary.withValues(alpha: 0.2),
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
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = highlighted ? cs.secondary : null;
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
            color: accent?.withValues(alpha: 0.15) ??
                (isDark ? Sanctuary.glass1 : Sanctuary.lightGlass1),
            border: Border.all(
              color: accent?.withValues(alpha: 0.4) ?? cs.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(Sanctuary.radiusSm),
          ),
          child: Icon(icon, size: 16, color: accent ?? cs.onSurface),
        ),
      ),
    );
  }
}

