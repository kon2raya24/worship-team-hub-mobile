import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../music_data.dart';
import 'quiz_game_scaffold.dart';

class IntervalsGameScreen extends StatelessWidget {
  const IntervalsGameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return QuizGameScaffold(
      title: 'Interval Trainer',
      newQuestion: _newQuestion,
      finishedMessage: (score, total) {
        if (score == total) {
          return 'Interval ear. Singers and instrumentalists alike will thank you.';
        }
        if (score >= 7) {
          return 'Strong. Mixing in m6 and m7 every round will lock in the trickier ones.';
        }
        return 'Worth a few more rounds — intervals are the alphabet of melody.';
      },
    );
  }
}

QuizQuestion _newQuestion() {
  final nameNote = pickOne([true, false]);
  final from = pickOne(keysForTranspose);
  final useFlats = keyUsesFlats(from);
  final intervalIdx = pickN(List.generate(intervals.length, (i) => i), 1).first;
  final interval = intervals[intervalIdx];
  final to = noteAbove(from, interval.semitones, useFlats: useFlats);

  if (nameNote) {
    // Distractor pool: notes at each of the other intervals from `from`.
    final pool = <String>{};
    for (var i = 0; i < intervals.length; i++) {
      if (i == intervalIdx) continue;
      pool.add(noteAbove(from, intervals[i].semitones, useFlats: useFlats));
    }
    pool.remove(to);
    final distractors = pickN(pool.toList(), 3);
    final options = pickN([to, ...distractors], 4);
    return QuizQuestion(
      prompt: _nameNotePrompt(from, interval),
      options: options,
      correctLabel: to,
    );
  }

  // Name the interval given two notes.
  final otherShorts = intervals
      .where((iv) => iv.short != interval.short)
      .map((iv) => iv.short)
      .toList();
  final distractors = pickN(otherShorts, 3);
  final options = pickN([interval.short, ...distractors], 4);
  return QuizQuestion(
    prompt: _nameIntervalPrompt(from, to),
    options: options,
    correctLabel: interval.short,
    optionDisplay: (short) {
      final iv = intervals.firstWhere((i) => i.short == short);
      return '${iv.short} · ${iv.name}';
    },
  );
}

Widget _nameNotePrompt(String from, MusicInterval interval) {
  return Text.rich(
    TextSpan(
      children: [
        const TextSpan(text: 'What note is a '),
        TextSpan(
          text: interval.short,
          style: const TextStyle(color: Sanctuary.auroraViolet, fontFamily: 'monospace'),
        ),
        TextSpan(
          text: ' (${interval.name})',
          style: const TextStyle(color: Sanctuary.muted),
        ),
        const TextSpan(text: ' above '),
        TextSpan(
          text: from,
          style: const TextStyle(color: Sanctuary.auroraCyan, fontFamily: 'monospace'),
        ),
        const TextSpan(text: '?'),
      ],
    ),
  );
}

Widget _nameIntervalPrompt(String from, String to) {
  return Text.rich(
    TextSpan(
      children: [
        const TextSpan(text: 'What interval is from '),
        TextSpan(
          text: from,
          style: const TextStyle(color: Sanctuary.auroraCyan, fontFamily: 'monospace'),
        ),
        const TextSpan(text: ' up to '),
        TextSpan(
          text: to,
          style: const TextStyle(color: Sanctuary.auroraViolet, fontFamily: 'monospace'),
        ),
        const TextSpan(text: '?'),
      ],
    ),
  );
}
