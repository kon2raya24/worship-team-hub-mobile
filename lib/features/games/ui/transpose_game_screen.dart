import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../songs/chordpro/chordpro.dart';
import '../music_data.dart';

const _roundsPerGame = 5;

class TransposeGameScreen extends StatefulWidget {
  const TransposeGameScreen({super.key});

  @override
  State<TransposeGameScreen> createState() => _TransposeGameScreenState();
}

class _Round {
  _Round({
    required this.fromKey,
    required this.toKey,
    required this.progression,
    required this.expected,
  });
  final String fromKey;
  final String toKey;
  final List<String> progression;
  final List<String> expected;
}

_Round _newRound() {
  final tpl = pickOne(progressions);
  final fromKey = pickOne(keysForTranspose);
  var toKey = pickOne(keysForTranspose);
  while (toKey == fromKey) {
    toKey = pickOne(keysForTranspose);
  }
  final fromShift = ChordPro.semitonesBetween('C', fromKey);
  final toShift = ChordPro.semitonesBetween('C', toKey);
  final progression = tpl.chords
      .map((c) => ChordPro.transposeChord(c, fromShift, keyUsesFlats(fromKey)))
      .toList();
  final expected = tpl.chords
      .map((c) => ChordPro.transposeChord(c, toShift, keyUsesFlats(toKey)))
      .toList();
  return _Round(
    fromKey: fromKey,
    toKey: toKey,
    progression: progression,
    expected: expected,
  );
}

class _TransposeGameScreenState extends State<TransposeGameScreen> {
  late List<_Round> _rounds;
  int _index = 0;
  late List<TextEditingController> _controllers;
  bool _submitted = false;
  int _score = 0;

  @override
  void initState() {
    super.initState();
    _rounds = List.generate(_roundsPerGame, (_) => _newRound());
    _bindControllers();
  }

  void _bindControllers() {
    _controllers =
        List.generate(_rounds[_index].progression.length, (_) => TextEditingController());
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _check() {
    final round = _rounds[_index];
    var correct = 0;
    for (var i = 0; i < round.expected.length; i++) {
      if (chordsEqual(_controllers[i].text, round.expected[i])) correct++;
    }
    setState(() {
      _submitted = true;
      if (correct == round.expected.length) _score++;
    });
  }

  void _next() {
    for (final c in _controllers) {
      c.dispose();
    }
    setState(() {
      _index++;
      _submitted = false;
    });
    _bindControllers();
  }

  void _restart() {
    for (final c in _controllers) {
      c.dispose();
    }
    setState(() {
      _rounds = List.generate(_roundsPerGame, (_) => _newRound());
      _index = 0;
      _score = 0;
      _submitted = false;
    });
    _bindControllers();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final successColor = isDark ? Sanctuary.success : Sanctuary.lightSuccess;
    final round = _rounds[_index];
    final isLast = _index == _rounds.length - 1;
    final finished = _submitted && isLast;
    final allCorrect = _submitted &&
        round.expected
            .asMap()
            .entries
            .every((e) => chordsEqual(_controllers[e.key].text, e.value));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 20),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/games'),
        ),
        title: const Text('Transpose Trainer'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Text(
                'Round ${_index + 1} / $_roundsPerGame',
                style: Sanctuary.mono(fontSize: 10, color: cs.onSurfaceVariant),
              ),
              const Spacer(),
              Text('Score',
                  style: Sanctuary.mono(
                      fontSize: 10, color: cs.onSurfaceVariant)),
              const SizedBox(width: 6),
              Text(
                '$_score / $_roundsPerGame',
                style: Sanctuary.display(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GlassCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('ORIGINAL',
                        style: Sanctuary.mono(
                            fontSize: 10, color: cs.onSurfaceVariant)),
                    const SizedBox(width: 8),
                    _KeyChip(label: round.fromKey, color: Sanctuary.auroraViolet),
                    const SizedBox(width: 10),
                    Icon(Icons.arrow_forward,
                        size: 14, color: cs.onSurfaceVariant),
                    const SizedBox(width: 10),
                    Text('TARGET',
                        style: Sanctuary.mono(
                            fontSize: 10, color: cs.onSurfaceVariant)),
                    const SizedBox(width: 8),
                    _KeyChip(label: round.toKey, color: Sanctuary.auroraCyan),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: round.progression
                      .map((c) => _ChordPill(label: c))
                      .toList(),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(round.expected.length, (i) {
                    final right = _submitted &&
                        chordsEqual(_controllers[i].text, round.expected[i]);
                    final wrong = _submitted && !right;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 84,
                          child: TextField(
                            controller: _controllers[i],
                            enabled: !_submitted,
                            textAlign: TextAlign.center,
                            style: Sanctuary.mono(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface,
                              letterSpacing: 0,
                            ),
                            decoration: InputDecoration(
                              hintText: '?',
                              isDense: true,
                              filled: true,
                              fillColor: right
                                  ? successColor.withValues(alpha: 0.12)
                                  : wrong
                                      ? cs.error.withValues(alpha: 0.12)
                                      : null,
                              enabledBorder: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(Sanctuary.radiusMd),
                                borderSide: BorderSide(
                                  color: right
                                      ? successColor.withValues(alpha: 0.5)
                                      : wrong
                                          ? cs.error.withValues(alpha: 0.5)
                                          : cs.outlineVariant,
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (wrong) ...[
                          const SizedBox(height: 2),
                          Text(
                            round.expected[i],
                            style: Sanctuary.mono(
                              fontSize: 11,
                              color: successColor,
                              letterSpacing: 0,
                            ),
                          ),
                        ],
                      ],
                    );
                  }),
                ),
                const SizedBox(height: 16),
                if (!_submitted)
                  FilledButton(
                    onPressed: _check,
                    child: const Text('Check answer'),
                  )
                else if (finished)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('GAME OVER',
                          style: Sanctuary.mono(
                              fontSize: 10, color: cs.onSurfaceVariant)),
                      const SizedBox(height: 4),
                      Text(
                        '$_score / $_roundsPerGame',
                        style: Sanctuary.display(fontSize: 26),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _score == _roundsPerGame
                            ? 'Perfect run. The band trusts you on key changes.'
                            : _score >= 3
                                ? "Solid — that 'play in F' request won't faze you."
                                : 'Keep going. The circle of fifths gets easier.',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _restart,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Play again'),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Text(
                        allCorrect ? '✓ Correct' : '✕ Not quite',
                        style: TextStyle(
                          color: allCorrect ? successColor : cs.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: _next,
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('Next round'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Tip: minor chords use lowercase m (Am). Flats use b (Bb), sharps use #.',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _KeyChip extends StatelessWidget {
  const _KeyChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(Sanctuary.radiusSm),
      ),
      child: Text(
        label,
        style: Sanctuary.mono(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _ChordPill extends StatelessWidget {
  const _ChordPill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: isDark ? Sanctuary.glass1 : Sanctuary.lightGlass1,
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(Sanctuary.radiusMd),
      ),
      child: Text(
        label,
        style: Sanctuary.mono(
          fontSize: 15,
          color: cs.onSurface,
          letterSpacing: 0,
        ),
      ),
    );
  }
}
