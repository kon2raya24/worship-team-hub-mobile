import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/supabase_client.dart';
import '../../../core/theme.dart';

final setlistsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
  final rows = await supabase
      .from('setlists')
      .select('id, service_date, theme')
      .gte('service_date', today)
      .order('service_date');
  return List<Map<String, dynamic>>.from(rows);
});

class SetlistsListScreen extends ConsumerWidget {
  const SetlistsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setlists = ref.watch(setlistsProvider);
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
          child: Text('Failed to load setlists.\n$e',
              style: const TextStyle(color: Sanctuary.muted)),
        ),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Text('No upcoming setlists.',
                  style: TextStyle(color: Sanctuary.muted)),
            );
          }
          return RefreshIndicator(
            color: Sanctuary.auroraCyan,
            onRefresh: () async => ref.invalidate(setlistsProvider),
            child: ListView.separated(
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

  final Map<String, dynamic> setlist;

  @override
  Widget build(BuildContext context) {
    final date = DateTime.parse(setlist['service_date'] as String);
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.calendar_today_outlined,
                color: Sanctuary.auroraViolet, size: 14),
            const SizedBox(width: 6),
            Text(DateFormat('EEE').format(date).toUpperCase(),
                style: Sanctuary.mono(
                    fontSize: 11, color: Sanctuary.auroraViolet)),
          ]),
          const SizedBox(height: 6),
          Text(DateFormat('EEEE, MMM d').format(date),
              style: Sanctuary.display(fontSize: 20)),
          if ((setlist['theme'] as String?)?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(setlist['theme'] as String,
                style: const TextStyle(
                    color: Sanctuary.muted, fontSize: 13)),
          ],
        ],
      ),
    );
  }
}
