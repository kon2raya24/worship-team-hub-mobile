import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
          onPressed: () => context.go('/songs'),
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
            initialTranspose: ChordPro.semitonesBetween(s.originalKey, targetKey),
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

  @override
  Widget build(BuildContext context) {
    final body = widget.chordproBody.trim();
    final parsed = body.isEmpty
        ? null
        : ChordPro.transpose(ChordPro.parse(body), _transpose);
    final currentKey = parsed?.key ?? widget.originalKey;

    return ListView(
      padding: const EdgeInsets.all(16),
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
          originalKey: widget.originalKey,
          transpose: _transpose,
          fontSize: _fontSize,
          onTransposeDown: () => setState(() => _transpose -= 1),
          onTransposeUp: () => setState(() => _transpose += 1),
          onTransposeReset: () => setState(() => _transpose = 0),
          onFontDown: () => setState(
            () => _fontSize = (_fontSize - 1).clamp(11, 22),
          ),
          onFontUp: () => setState(
            () => _fontSize = (_fontSize + 1).clamp(11, 22),
          ),
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
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.currentKey,
    required this.originalKey,
    required this.transpose,
    required this.fontSize,
    required this.onTransposeDown,
    required this.onTransposeUp,
    required this.onTransposeReset,
    required this.onFontDown,
    required this.onFontUp,
  });

  final String? currentKey;
  final String? originalKey;
  final int transpose;
  final double fontSize;
  final VoidCallback onTransposeDown;
  final VoidCallback onTransposeUp;
  final VoidCallback onTransposeReset;
  final VoidCallback onFontDown;
  final VoidCallback onFontUp;

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
          Text(
            label,
            style: Sanctuary.mono(fontSize: 10, color: accent),
          ),
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
  const _IconBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
            color: Sanctuary.glass1,
            border: Border.all(color: Sanctuary.hairline),
            borderRadius: BorderRadius.circular(Sanctuary.radiusSm),
          ),
          child: Icon(icon, size: 16, color: Sanctuary.foreground),
        ),
      ),
    );
  }
}
