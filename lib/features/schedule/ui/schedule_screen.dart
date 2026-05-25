import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../../data/db/app_db.dart';
import '../../../data/sync/providers.dart';
import '../../../data/sync/sync_service.dart';

class ScheduleScreen extends ConsumerWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignments = ref.watch(upcomingScheduleStreamProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 20),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: const Text('Sunday schedule'),
      ),
      body: assignments.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            'Failed to load schedule.\n$e',
            style: const TextStyle(color: Sanctuary.muted),
          ),
        ),
        data: (rows) {
          final grouped = _groupByDate(rows);
          return RefreshIndicator(
            color: Sanctuary.auroraCyan,
            onRefresh: () => ref.read(syncServiceProvider).syncAll(),
            child: grouped.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 120),
                      Center(
                        child: Text(
                          'No upcoming assignments.\nPull to sync.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Sanctuary.muted),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: grouped.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      final entry = grouped[i];
                      return _ScheduleCard(
                        date: entry.key,
                        assignments: entry.value,
                        isFirst: i == 0,
                      );
                    },
                  ),
          );
        },
      ),
    );
  }

  List<MapEntry<DateTime, List<UpcomingAssignment>>> _groupByDate(
    List<UpcomingAssignment> rows,
  ) {
    final map = <DateTime, List<UpcomingAssignment>>{};
    for (final r in rows) {
      final date = DateTime(
        r.assignment.serviceDate.year,
        r.assignment.serviceDate.month,
        r.assignment.serviceDate.day,
      );
      map.putIfAbsent(date, () => []).add(r);
    }
    final entries = map.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return entries;
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({
    required this.date,
    required this.assignments,
    required this.isFirst,
  });

  final DateTime date;
  final List<UpcomingAssignment> assignments;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    final accent = isFirst ? Sanctuary.auroraCyan : Sanctuary.auroraViolet;
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                isFirst ? 'THIS SUNDAY' : 'UPCOMING',
                style: Sanctuary.mono(fontSize: 10, color: accent),
              ),
              const Spacer(),
              Text(
                '${assignments.length} assigned',
                style: const TextStyle(color: Sanctuary.muted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            DateFormat('EEEE, MMM d').format(date),
            style: Sanctuary.display(fontSize: 18),
          ),
          const SizedBox(height: 12),
          ...assignments.map(_assignmentRow),
        ],
      ),
    );
  }

  Widget _assignmentRow(UpcomingAssignment a) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Sanctuary.auroraCyan.withValues(alpha: 0.1),
              border: Border.all(
                color: Sanctuary.auroraCyan.withValues(alpha: 0.25),
              ),
              borderRadius: BorderRadius.circular(Sanctuary.radiusSm),
            ),
            child: Text(
              a.assignment.role.toUpperCase(),
              style: Sanctuary.mono(
                fontSize: 9,
                color: Sanctuary.auroraCyan,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              a.memberName,
              style: const TextStyle(
                color: Sanctuary.foreground,
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
