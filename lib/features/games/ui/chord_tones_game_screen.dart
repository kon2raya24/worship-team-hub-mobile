import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../music_data.dart';
import 'quiz_game_scaffold.dart';

enum _ChordType { major, minor, maj7, dom7 }

class _ChordTypeInfo {
  const _ChordTypeInfo({
    required this.type,
    required this.label,
    required this.suffix,
    required this.tones,
  });
  final _ChordType type;
  final String label;
  final String suffix;
  final List<_ToneSpec> tones;
}

class _ToneSpec {
  const _ToneSpec({required this.name, required this.semi});
  final String name;
  final int semi;
}

const _chordTypes = <_ChordTypeInfo>[
  _ChordTypeInfo(type: _ChordType.major, label: 'major', suffix: '', tones: [
    _ToneSpec(name: 'root', semi: 0),
    _ToneSpec(name: '3rd', semi: 4),
    _ToneSpec(name: '5th', semi: 7),
  ]),
  _ChordTypeInfo(type: _ChordType.minor, label: 'minor', suffix: 'm', tones: [
    _ToneSpec(name: 'root', semi: 0),
    _ToneSpec(name: '♭3rd', semi: 3),
    _ToneSpec(name: '5th', semi: 7),
  ]),
  _ChordTypeInfo(type: _ChordType.maj7, label: 'major 7', suffix: 'maj7', tones: [
    _ToneSpec(name: 'root', semi: 0),
    _ToneSpec(name: '3rd', semi: 4),
    _ToneSpec(name: '5th', semi: 7),
    _ToneSpec(name: '7th', semi: 11),
  ]),
  _ChordTypeInfo(type: _ChordType.dom7, label: 'dominant 7', suffix: '7', tones: [
    _ToneSpec(name: 'root', semi: 0),
    _ToneSpec(name: '3rd', semi: 4),
    _ToneSpec(name: '5th', semi: 7),
    _ToneSpec(name: '♭7th', semi: 10),
  ]),
];

class ChordTonesGameScreen extends StatelessWidget {
  const ChordTonesGameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return QuizGameScaffold(
      title: 'Chord Tones',
      newQuestion: _newQuestion,
      finishedMessage: (score, total) {
        if (score == total) {
          return "Vocal-section gold. You'll never sing the wrong harmony note again.";
        }
        if (score >= 7) {
          return 'Strong. The dominant 7 is the one most worship singers miss — drill that.';
        }
        return 'Worth a few more rounds — chord tones are the bones of every harmony.';
      },
    );
  }
}

QuizQuestion _newQuestion() {
  final ct = pickOne(_chordTypes);
  final root = pickOne(keysForTranspose);
  final useFlats = keyUsesFlats(root);
  final target = pickOne(ct.tones);
  final correct = noteAbove(root, target.semi, useFlats: useFlats);

  // Distractors: other chord tones plus ±1 semitone neighbours so the
  // common 3rd-vs-♭3rd error is the actual mistake to make.
  final pool = <String>{};
  for (final t in ct.tones) {
    if (t.name == target.name) continue;
    pool.add(noteAbove(root, t.semi, useFlats: useFlats));
  }
  pool.add(noteAbove(root, target.semi + 1, useFlats: useFlats));
  pool.add(noteAbove(root, target.semi - 1, useFlats: useFlats));
  pool.remove(correct);
  final distractors = pickN(pool.toList(), 3);
  final options = pickN([correct, ...distractors], 4);

  return QuizQuestion(
    prompt: _prompt(root, ct, target),
    options: options,
    correctLabel: correct,
  );
}

Widget _prompt(String root, _ChordTypeInfo ct, _ToneSpec tone) {
  return Text.rich(
    TextSpan(
      children: [
        const TextSpan(text: "What's the "),
        TextSpan(
          text: tone.name,
          style: const TextStyle(color: Sanctuary.auroraViolet, fontFamily: 'monospace'),
        ),
        const TextSpan(text: ' of '),
        TextSpan(
          text: '$root${ct.suffix}',
          style: const TextStyle(color: Sanctuary.auroraCyan, fontFamily: 'monospace'),
        ),
        TextSpan(
          text: ' (${ct.label})',
          style: const TextStyle(color: Sanctuary.muted),
        ),
        const TextSpan(text: '?'),
      ],
    ),
  );
}
