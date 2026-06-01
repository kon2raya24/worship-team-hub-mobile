import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';

/// One quiz question shown to the player.
class QuizQuestion {
  const QuizQuestion({
    required this.prompt,
    required this.options,
    required this.correctLabel,
    this.optionDisplay,
  });

  /// The question prompt (typically a `Text.rich` with coloured spans).
  final Widget prompt;

  /// Multiple-choice options. The string value is compared against
  /// [correctLabel] to score.
  final List<String> options;

  /// The option value considered "correct".
  final String correctLabel;

  /// Optional override for how an option is shown to the player. Used when
  /// the value (e.g. "P5") differs from what should be visible
  /// (e.g. "P5 · Perfect 5th").
  final String Function(String value)? optionDisplay;
}

/// Boilerplate scaffold for a 10-round multiple-choice game. Handles the
/// score/progress header, option buttons, next/finish UI and restart so each
/// game file can focus on generating its own questions.
class QuizGameScaffold extends StatefulWidget {
  const QuizGameScaffold({
    super.key,
    required this.title,
    required this.newQuestion,
    this.roundsPerGame = 10,
    this.finishedMessage,
  });

  final String title;
  final QuizQuestion Function() newQuestion;
  final int roundsPerGame;

  /// Optional flavour text shown under the final score. Defaults to a generic
  /// well-done line.
  final String Function(int score, int total)? finishedMessage;

  @override
  State<QuizGameScaffold> createState() => _QuizGameScaffoldState();
}

class _QuizGameScaffoldState extends State<QuizGameScaffold> {
  late List<QuizQuestion> _questions;
  int _index = 0;
  String? _picked;
  int _score = 0;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  void _generate() {
    _questions = List.generate(widget.roundsPerGame, (_) => widget.newQuestion());
  }

  void _restart() {
    setState(() {
      _generate();
      _index = 0;
      _picked = null;
      _score = 0;
    });
  }

  void _choose(String opt) {
    if (_picked != null) return;
    final q = _questions[_index];
    setState(() {
      _picked = opt;
      if (opt == q.correctLabel) _score++;
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
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final successColor = isDark ? Sanctuary.success : Sanctuary.lightSuccess;
    final q = _questions[_index];
    final isLast = _index == _questions.length - 1;
    final finished = _picked != null && isLast;
    final isCorrect = _picked != null && _picked == q.correctLabel;
    final total = widget.roundsPerGame;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 20),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/games'),
        ),
        title: Text(widget.title),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Text('Question ${_index + 1} / $total',
                  style: Sanctuary.mono(
                      fontSize: 10, color: cs.onSurfaceVariant)),
              const Spacer(),
              Text('Score',
                  style: Sanctuary.mono(
                      fontSize: 10, color: cs.onSurfaceVariant)),
              const SizedBox(width: 6),
              Text(
                '$_score / $total',
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
                Text('QUESTION',
                    style: Sanctuary.mono(
                        fontSize: 10, color: cs.onSurfaceVariant)),
                const SizedBox(height: 6),
                DefaultTextStyle.merge(
                  style: Sanctuary.display(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  child: q.prompt,
                ),
                const SizedBox(height: 16),
                ...q.options.map((opt) {
                  final isPick = _picked == opt;
                  final isRight = _picked != null && opt == q.correctLabel;
                  Color bg = isDark ? Sanctuary.glass1 : Sanctuary.lightGlass1;
                  Color border = cs.outlineVariant;
                  if (_picked != null) {
                    if (isRight) {
                      bg = successColor.withValues(alpha: 0.15);
                      border = successColor.withValues(alpha: 0.5);
                    } else if (isPick) {
                      bg = cs.error.withValues(alpha: 0.15);
                      border = cs.error.withValues(alpha: 0.5);
                    }
                  }
                  final display = q.optionDisplay != null
                      ? q.optionDisplay!(opt)
                      : opt;
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
                              Expanded(
                                child: Text(
                                  display,
                                  style: Sanctuary.mono(
                                    fontSize: 15,
                                    color: cs.onSurface,
                                    letterSpacing: 0,
                                  ),
                                ),
                              ),
                              if (_picked != null && isRight)
                                Icon(Icons.check,
                                    size: 16, color: successColor),
                              if (_picked != null && isPick && !isRight)
                                Icon(Icons.close, size: 16, color: cs.error),
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
                      Expanded(
                        child: Text(
                          isCorrect
                              ? 'Correct'
                              : 'Answer: ${q.optionDisplay != null ? q.optionDisplay!(q.correctLabel) : q.correctLabel}',
                          style: TextStyle(
                            color: isCorrect ? successColor : cs.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      FilledButton(
                        onPressed: _next,
                        child: const Text('Next'),
                      ),
                    ],
                  ),
                if (finished) ...[
                  const SizedBox(height: 8),
                  Text('DONE',
                      style: Sanctuary.mono(
                          fontSize: 10, color: cs.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  Text(
                    '$_score / $total',
                    style: Sanctuary.display(fontSize: 26),
                  ),
                  if (widget.finishedMessage != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      widget.finishedMessage!(_score, total),
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
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
