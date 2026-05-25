import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../../data/db/app_db.dart';
import '../../../data/sync/providers.dart';
import '../../../data/sync/sync_service.dart';

class SetlistsListScreen extends ConsumerWidget {
  const SetlistsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setlists = ref.watch(upcomingSetlistsStreamProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 20),
          onPressed: () => context.go('/'),
        ),
        title: const Text('Setlists'),
      ),
      body: setlists.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            'Failed to load setlists.\n$e',
            style: const TextStyle(color: Sanctuary.muted),
          ),
        ),
        data: (list) {
          return RefreshIndicator(
            color: Sanctuary.auroraCyan,
            onRefresh: () => ref.read(syncServiceProvider).syncAll(),
            child: list.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 120),
                      Center(
                        child: Text(
                          'No upcoming setlists.\nPull to sync.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Sanctuary.muted),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _SetlistCard(setlist: list[i]),
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
    final date = setlist.serviceDate;
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                color: Sanctuary.auroraViolet,
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                DateFormat('EEE').format(date).toUpperCase(),
                style: Sanctuary.mono(
                  fontSize: 11,
                  color: Sanctuary.auroraViolet,
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
              style: const TextStyle(color: Sanctuary.muted, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}
