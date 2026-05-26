import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../music_data.dart';
import 'quiz_game_scaffold.dart';

// vii° is rare in worship — stick to the six diatonic chords leaders
// actually cue from the stage (I, ii, iii, IV, V, vi).
const _degrees = [0, 1, 2, 3, 4, 5];

class NashvilleGameScreen extends StatelessWidget {
  const NashvilleGameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return QuizGameScaffold(
      title: 'Nashville Number Trainer',
      newQuestion: _newQuestion,
      finishedMessage: (score, total) {
        if (score == total) {
          return "Nashville-fluent. The band hears 'go to the IV' and you're already there.";
        }
        if (score >= 7) {
          return "Solid. Spend a Sunday cueing chords by number and it'll click.";
        }
        return 'Worth a few more rounds — leaders call chords by number all the time.';
      },
    );
  }
}

QuizQuestion _newQuestion() {
  final findChord = pickOne([true, false]);
  final key = pickOne(keysForTranspose);
  final degree = pickOne(_degrees);
  final chord = diatonicChord(key, degree);

  if (findChord) {
    // Distractors are other diatonic chords from the same key.
    final otherDegrees = _degrees.where((d) => d != degree).toList();
    final distractors =
        pickN(otherDegrees, 3).map((d) => diatonicChord(key, d)).toList();
    final options = pickN([chord, ...distractors], 4);
    return QuizQuestion(
      prompt: _findChordPrompt(key, degree),
      options: options,
      correctLabel: chord,
    );
  }

  final otherDegrees = _degrees.where((d) => d != degree).toList();
  final distractorDegrees = pickN(otherDegrees, 3);
  final indices = pickN([degree, ...distractorDegrees], 4);
  return QuizQuestion(
    prompt: _findDegreePrompt(key, chord),
    options: indices.map((d) => '$d').toList(),
    correctLabel: '$degree',
    optionDisplay: (val) => romanNumerals[int.parse(val)],
  );
}

Widget _findChordPrompt(String key, int degree) {
  return Text.rich(
    TextSpan(
      children: [
        const TextSpan(text: 'In the key of '),
        TextSpan(
          text: key,
          style: const TextStyle(color: Sanctuary.auroraCyan, fontFamily: 'monospace'),
        ),
        const TextSpan(text: ', what chord is the '),
        TextSpan(
          text: romanNumerals[degree],
          style: const TextStyle(color: Sanctuary.auroraViolet, fontFamily: 'monospace'),
        ),
        const TextSpan(text: '?'),
      ],
    ),
  );
}

Widget _findDegreePrompt(String key, String chord) {
  return Text.rich(
    TextSpan(
      children: [
        const TextSpan(text: 'In the key of '),
        TextSpan(
          text: key,
          style: const TextStyle(color: Sanctuary.auroraCyan, fontFamily: 'monospace'),
        ),
        const TextSpan(text: ', '),
        TextSpan(
          text: chord,
          style: const TextStyle(color: Sanctuary.auroraViolet, fontFamily: 'monospace'),
        ),
        const TextSpan(text: ' is which Roman numeral?'),
      ],
    ),
  );
}
