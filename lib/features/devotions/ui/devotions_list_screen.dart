import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../../data/db/app_db.dart';
import '../../../data/sync/providers.dart';
import '../../../data/sync/sync_service.dart';
import '../../auth/auth_provider.dart';

class DevotionsListScreen extends ConsumerWidget {
  const DevotionsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final devotions = ref.watch(devotionsStreamProvider);
    final isLeader = ref.watch(isLeaderProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 20),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: const Text('Devotions'),
      ),
      floatingActionButton: isLeader
          ? FloatingActionButton.extended(
              backgroundColor: Sanctuary.auroraAmber,
              foregroundColor: Sanctuary.ink0,
              onPressed: () => context.push('/devotions/new'),
              icon: const Icon(Icons.add),
              label: const Text('New'),
            )
          : null,
      body: devotions.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Failed to load.\n$e',
              style: TextStyle(color: cs.onSurfaceVariant)),
        ),
        data: (list) => RefreshIndicator(
          color: cs.secondary,
          onRefresh: () => ref.read(syncServiceProvider).syncAll(),
          child: list.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 120),
                    Center(
                      child: EmptyState(
                        icon: Icons.auto_stories_outlined,
                        title: 'No devotions yet',
                        subtitle: 'Pull down to sync.',
                      ),
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _Row(d: list[i]),
                ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.d});
  final DevotionRow d;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(Sanctuary.radiusLg),
        onTap: () => context.push('/devotions/${d.id}'),
        child: GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat('MMM d').format(d.publishedAt).toUpperCase(),
                style: Sanctuary.mono(
                    fontSize: 10, color: Sanctuary.auroraAmber),
              ),
              const SizedBox(height: 6),
              Text(d.title,
                  style: Sanctuary.display(
                      fontSize: 17, fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              if ((d.scriptureRef ?? '').isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(d.scriptureRef!,
                    style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 13,
                        fontStyle: FontStyle.italic)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
