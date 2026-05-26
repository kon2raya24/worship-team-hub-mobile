import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../music_data.dart';
import 'quiz_game_scaffold.dart';

class RelativeGameScreen extends StatelessWidget {
  const RelativeGameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return QuizGameScaffold(
      title: 'Relative Key',
      newQuestion: _newQuestion,
      finishedMessage: (score, total) {
        if (score == total) {
          return 'Major / minor pairings on autopilot. Reharmonizations are now in reach.';
        }
        if (score >= 7) {
          return 'Strong. The minor 3rd-below pattern (C → A, G → E, …) is the shortcut.';
        }
        return 'Worth a few more rounds — relative keys unlock half of every worship reharm.';
      },
    );
  }
}

QuizQuestion _newQuestion() {
  final majorToMinor = pickOne([true, false]);

  if (majorToMinor) {
    final majorKey = pickOne(keysForTranspose);
    final correct = relativeMinor(majorKey);
    final otherMajors =
        keysForTranspose.where((k) => k != majorKey).toList();
    final distractors = pickN(otherMajors, 3).map(relativeMinor).toList();
    final options = pickN({correct, ...distractors}.toList(), 4);
    while (options.length < 4) {
      final extra = relativeMinor(pickOne(keysForTranspose));
      if (!options.contains(extra)) options.add(extra);
    }
    return QuizQuestion(
      prompt: _majorToMinorPrompt(majorKey),
      options: options,
      correctLabel: correct,
    );
  }

  final sourceMajor = pickOne(keysForTranspose);
  final minorKey = relativeMinor(sourceMajor);
  final correct = relativeMajor(minorKey);
  final otherMajors = keysForTranspose.where((k) => k != correct).toList();
  final distractors = pickN(otherMajors, 3);
  final options = pickN([correct, ...distractors], 4);
  return QuizQuestion(
    prompt: _minorToMajorPrompt(minorKey),
    options: options,
    correctLabel: correct,
  );
}

Widget _majorToMinorPrompt(String majorKey) {
  return Text.rich(
    TextSpan(
      children: [
        const TextSpan(text: "What's the relative minor of "),
        TextSpan(
          text: majorKey,
          style: const TextStyle(color: Sanctuary.auroraCyan, fontFamily: 'monospace'),
        ),
        const TextSpan(text: ' major?'),
      ],
    ),
  );
}

Widget _minorToMajorPrompt(String minorKey) {
  return Text.rich(
    TextSpan(
      children: [
        const TextSpan(text: "What's the relative major of "),
        TextSpan(
          text: minorKey,
          style: const TextStyle(color: Sanctuary.auroraCyan, fontFamily: 'monospace'),
        ),
        const TextSpan(text: '?'),
      ],
    ),
  );
}
