import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../../data/sync/providers.dart';

class DevotionDetailScreen extends ConsumerWidget {
  const DevotionDetailScreen({super.key, required this.devotionId});

  final String devotionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final d = ref.watch(devotionByIdProvider(devotionId));
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 20),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/devotions'),
        ),
        title: const Text('Devotion'),
      ),
      body: d.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Failed to load.\n$e',
              style: TextStyle(color: cs.onSurfaceVariant)),
        ),
        data: (d) {
          if (d == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Not in local cache.\nSync from the home screen.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                DateFormat.yMMMMd().format(d.publishedAt).toUpperCase(),
                style:
                    Sanctuary.mono(fontSize: 10, color: Sanctuary.auroraAmber),
              ),
              const SizedBox(height: 8),
              Text(d.title, style: Sanctuary.display(fontSize: 26)),
              if ((d.scriptureRef ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(d.scriptureRef!,
                    style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 14,
                        fontStyle: FontStyle.italic)),
              ],
              const SizedBox(height: 16),
              GlassCard(
                padding: const EdgeInsets.all(18),
                child: MarkdownBody(
                  data: d.body,
                  styleSheet: MarkdownStyleSheet(
                    p: TextStyle(
                        color: cs.onSurface,
                        fontSize: 15,
                        height: 1.55),
                    h1: Sanctuary.display(fontSize: 22),
                    h2: Sanctuary.display(fontSize: 18),
                    h3: Sanctuary.display(fontSize: 16),
                    blockquoteDecoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                            color:
                                Sanctuary.auroraCyan.withValues(alpha: 0.6),
                            width: 3),
                      ),
                    ),
                    blockquote: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 14,
                        fontStyle: FontStyle.italic),
                    a: const TextStyle(
                        color: Sanctuary.auroraCyan,
                        decoration: TextDecoration.underline),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
