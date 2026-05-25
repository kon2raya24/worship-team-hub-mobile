import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../music_data.dart';

const _rounds = 10;
const _keys = ['C', 'G', 'D', 'A', 'E', 'B', 'F#', 'F', 'Bb', 'Eb', 'Ab', 'Db'];

class KeysGameScreen extends StatefulWidget {
  const KeysGameScreen({super.key});

  @override
  State<KeysGameScreen> createState() => _KeysGameScreenState();
}

abstract class _Question {
  String get prompt;
  List<String> get options;
  String get correctLabel;
}

class _CountQuestion implements _Question {
  _CountQuestion(this.key)
      : correctCount = keySignatures[key]!.accidentalCount,
        kind = keySignatures[key]!.usesFlats ? 'flats' : 'sharps';
  final String key;
  final int correctCount;
  final String kind;

  @override
  String get prompt => 'How many accidentals does $key major have?';

  @override
  List<String> get options {
    final pool = [0, 1, 2, 3, 4, 5, 6]..remove(correctCount);
    final distractors = pickN(pool, 3);
    return pickN([correctCount, ...distractors], 4).map((n) => '$n').toList();
  }

  @override
  String get correctLabel => '$correctCount';
}

class _NameQuestion implements _Question {
  _NameQuestion(this.key) : sig = keySignatures[key]!;
  final String key;
  final KeySignature sig;

  @override
  String get prompt {
    final accidentals = sig.usesFlats ? sig.flats : sig.sharps;
    return 'Which major key has these ${sig.usesFlats ? "flats" : "sharps"}?\n'
        '${accidentals.join(", ")}';
  }

  @override
  List<String> get options {
    final sameKind = _keys.where((k) {
      final s = keySignatures[k]!;
      return s.usesFlats == sig.usesFlats && s.accidentalCount > 0 && k != key;
    }).toList();
    final distractors = pickN(sameKind, 3);
    return pickN([key, ...distractors], 4);
  }

  @override
  String get correctLabel => key;
}

_Question _newQuestion() {
  final wantName = pickOne([true, false]);
  final candidates =
      wantName ? _keys.where((k) => keySignatures[k]!.accidentalCount > 0).toList() : _keys;
  final key = pickOne(candidates);
  return wantName ? _NameQuestion(key) : _CountQuestion(key);
}

class _KeysGameScreenState extends State<KeysGameScreen> {
  late List<_Question> _questions;
  late List<List<String>> _options;
  int _index = 0;
  String? _picked;
  int _score = 0;

  @override
  void initState() {
    super.initState();
    _restart();
  }

  void _restart() {
    final qs = List.generate(_rounds, (_) => _newQuestion());
    setState(() {
      _questions = qs;
      _options = qs.map((q) => q.options).toList();
      _index = 0;
      _picked = null;
      _score = 0;
    });
  }

  void _choose(String opt) {
    if (_picked != null) return;
    final correct = opt == _questions[_index].correctLabel;
    setState(() {
      _picked = opt;
      if (correct) _score++;
    });
  }

  void _next() {
    setState(() {
      _index++;
      _picked = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final q = _questions[_index];
    final isLast = _index == _questions.length - 1;
    final finished = _picked != null && isLast;
    final isCorrect = _picked != null && _picked == q.correctLabel;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 20),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/games'),
        ),
        title: const Text('Key Signature Quiz'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Text('Question ${_index + 1} / $_rounds',
                  style: Sanctuary.mono(fontSize: 10)),
              const Spacer(),
              Text('Score', style: Sanctuary.mono(fontSize: 10)),
              const SizedBox(width: 6),
              Text(
                '$_score / $_rounds',
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
                Text('QUESTION', style: Sanctuary.mono(fontSize: 10)),
                const SizedBox(height: 6),
                Text(
                  q.prompt,
                  style: Sanctuary.display(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                ..._options[_index].map((opt) {
                  final isPick = _picked == opt;
                  final isRight = _picked != null && opt == q.correctLabel;
                  Color bg = Sanctuary.glass1;
                  Color border = Sanctuary.hairline;
                  if (_picked != null) {
                    if (isRight) {
                      bg = Sanctuary.success.withValues(alpha: 0.15);
                      border = Sanctuary.success.withValues(alpha: 0.5);
                    } else if (isPick) {
                      bg = Sanctuary.destructive.withValues(alpha: 0.15);
                      border = Sanctuary.destructive.withValues(alpha: 0.5);
                    }
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _picked == null ? () => _choose(opt) : null,
                        borderRadius: BorderRadius.circular(Sanctuary.radiusMd),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: bg,
                            border: Border.all(color: border),
                            borderRadius:
                                BorderRadius.circular(Sanctuary.radiusMd),
                          ),
                          child: Row(
                            children: [
                              Text(opt,
                                  style: Sanctuary.mono(
                                      fontSize: 15,
                                      color: Sanctuary.foreground,
                                      letterSpacing: 0)),
                              const Spacer(),
                              if (_picked != null && isRight)
                                const Icon(Icons.check, size: 16, color: Sanctuary.success),
                              if (_picked != null && isPick && !isRight)
                                const Icon(Icons.close,
                                    size: 16, color: Sanctuary.destructive),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                if (_picked != null && !finished)
                  Row(
                    children: [
                      Text(
                        isCorrect ? 'Correct' : 'Answer: ${q.correctLabel}',
                        style: TextStyle(
                          color: isCorrect
                              ? Sanctuary.success
                              : Sanctuary.destructive,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: _next,
                        child: const Text('Next'),
                      ),
                    ],
                  ),
                if (finished) ...[
                  const SizedBox(height: 8),
                  Text('DONE', style: Sanctuary.mono(fontSize: 10)),
                  const SizedBox(height: 4),
                  Text(
                    '$_score / $_rounds',
                    style: Sanctuary.display(fontSize: 26),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _restart,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Play again'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
