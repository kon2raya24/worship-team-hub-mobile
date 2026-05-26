import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../music_data.dart';
import 'quiz_game_scaffold.dart';

const _shapes = ['C', 'G', 'D', 'A', 'E'];
const _capoFrets = [0, 1, 2, 3, 4, 5, 6, 7];
// Worship-common target keys for the reverse-mode question.
const _targetKeys = ['C', 'G', 'D', 'A', 'E', 'F', 'Bb', 'Eb'];

class CapoGameScreen extends StatelessWidget {
  const CapoGameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return QuizGameScaffold(
      title: 'Capo Calculator',
      newQuestion: _newQuestion,
      finishedMessage: (score, total) {
        if (score == total) {
          return 'Capo math on autopilot. Leader changes the key two minutes before service — no problem.';
        }
        if (score >= 7) {
          return "Good. Practice the awkward keys (Eb, F) and you'll never freeze on a key change.";
        }
        return 'Worth a few more rounds — capo math saves a lot of stage panic.';
      },
    );
  }
}

QuizQuestion _newQuestion() {
  final findKey = pickOne([true, false]);

  if (findKey) {
    final shape = pickOne(_shapes);
    final capo = pickOne(_capoFrets);
    final correct = shapeWithCapo(shape, capo);
    final otherCapos = _capoFrets.where((c) => c != capo).toList();
    final distractors =
        pickN(otherCapos, 3).map((c) => shapeWithCapo(shape, c)).toList();
    final options = pickN({correct, ...distractors}.toList(), 4);
    // Re-pad if dedupe collapsed distractors below 4 options.
    while (options.length < 4) {
      final extra = shapeWithCapo(shape, pickOne(_capoFrets));
      if (!options.contains(extra)) options.add(extra);
    }
    return QuizQuestion(
      prompt: _findKeyPrompt(shape, capo),
      options: options,
      correctLabel: correct,
    );
  }

  // Reverse: pick a target key + shape, find the capo that reaches it.
  for (var tries = 0; tries < 20; tries++) {
    final targetKey = pickOne(_targetKeys);
    final shape = pickOne(_shapes);
    final capo = _capoFrets.firstWhere(
      (c) => shapeWithCapo(shape, c) == targetKey,
      orElse: () => -1,
    );
    if (capo == -1) continue;
    final otherFrets = _capoFrets.where((c) => c != capo).toList();
    final distractors = pickN(otherFrets, 3);
    final options =
        pickN([capo, ...distractors], 4).map((c) => '$c').toList();
    return QuizQuestion(
      prompt: _findCapoPrompt(shape, targetKey),
      options: options,
      correctLabel: '$capo',
      optionDisplay: (val) =>
          val == '0' ? 'Open (no capo)' : 'Fret $val',
    );
  }
  // Vanishingly unlikely fallthrough — return a guaranteed-valid question.
  return _newQuestion();
}

Widget _findKeyPrompt(String shape, int capo) {
  return Text.rich(
    TextSpan(
      children: [
        const TextSpan(text: "You're playing the "),
        TextSpan(
          text: shape,
          style: const TextStyle(color: Sanctuary.auroraCyan, fontFamily: 'monospace'),
        ),
        const TextSpan(text: ' shape with '),
        TextSpan(
          text: capo == 0 ? 'no capo' : 'capo at fret $capo',
          style: const TextStyle(color: Sanctuary.auroraViolet, fontFamily: 'monospace'),
        ),
        const TextSpan(text: '. What key is sounding?'),
      ],
    ),
  );
}

Widget _findCapoPrompt(String shape, String targetKey) {
  return Text.rich(
    TextSpan(
      children: [
        const TextSpan(text: 'Service is in '),
        TextSpan(
          text: targetKey,
          style: const TextStyle(color: Sanctuary.auroraCyan, fontFamily: 'monospace'),
        ),
        const TextSpan(text: '. You want to play '),
        TextSpan(
          text: shape,
          style: const TextStyle(color: Sanctuary.auroraViolet, fontFamily: 'monospace'),
        ),
        const TextSpan(text: ' shape — where does the capo go?'),
      ],
    ),
  );
}
