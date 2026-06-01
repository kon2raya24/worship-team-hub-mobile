import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../../data/db/app_db.dart';
import '../../../data/sync/providers.dart';
import '../../../data/sync/sync_service.dart';
import '../../auth/auth_provider.dart';

class SetlistsListScreen extends ConsumerWidget {
  const SetlistsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final setlists = ref.watch(upcomingSetlistsStreamProvider);
    final past = ref.watch(pastSetlistsStreamProvider).valueOrNull ??
        const <SetlistRow>[];
    final isLeader = ref.watch(isLeaderProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 20),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: const Text('Setlists'),
      ),
      floatingActionButton: isLeader
          ? FloatingActionButton.extended(
              backgroundColor: cs.secondary,
              foregroundColor: cs.onSecondary,
              onPressed: () => context.push('/setlists/new'),
              icon: const Icon(Icons.add),
              label: const Text('New'),
            )
          : null,
      body: setlists.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            'Failed to load setlists.\n$e',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        ),
        data: (list) {
          final hasAny = list.isNotEmpty || past.isNotEmpty;
          return RefreshIndicator(
            color: cs.secondary,
            onRefresh: () => ref.read(syncServiceProvider).syncAll(),
            child: !hasAny
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 120),
                      Center(
                        child: EmptyState(
                          icon: Icons.queue_music_outlined,
                          title: 'No setlists yet',
                          subtitle: 'Pull down to sync.',
                        ),
                      ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      for (final s in list) ...[
                        _SetlistCard(setlist: s),
                        const SizedBox(height: 10),
                      ],
                      if (past.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 10),
                          child: Text(
                            'PAST',
                            style: Sanctuary.mono(
                              fontSize: 11,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                        for (final s in past) ...[
                          _SetlistCard(setlist: s),
                          const SizedBox(height: 10),
                        ],
                      ],
                    ],
                  ),
          );
        },
      ),
    );
  }
}

class _SetlistCard extends StatelessWidget {
  const _SetlistCard({required this.setlist});

  final SetlistRow setlist;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final date = setlist.serviceDate;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(Sanctuary.radiusLg),
        onTap: () => context.push('/setlists/${setlist.id}'),
        child: GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    color: cs.primary,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    DateFormat('EEE').format(date).toUpperCase(),
                    style: Sanctuary.mono(
                      fontSize: 11,
                      color: cs.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                DateFormat('EEEE, MMM d').format(date),
                style: Sanctuary.display(fontSize: 20),
              ),
              if ((setlist.theme ?? '').isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  setlist.theme!,
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
