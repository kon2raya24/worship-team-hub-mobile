import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../../data/db/app_db.dart';
import '../../../data/sync/providers.dart';
import '../../../data/sync/sync_service.dart';
import '../../auth/auth_provider.dart';

const _roles = [
  'lead_vocal',
  'vocals',
  'acoustic',
  'electric',
  'bass',
  'keys',
  'drums',
  'tech',
];

class ScheduleScreen extends ConsumerWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignments = ref.watch(upcomingScheduleStreamProvider);
    final isLeader = ref.watch(isLeaderProvider);
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
          child: Text('Failed to load schedule.\n$e',
              style: const TextStyle(color: Sanctuary.muted)),
        ),
        data: (rows) {
          final dates = _nextFourSundays();
          final byDate = <DateTime, List<UpcomingAssignment>>{};
          for (final r in rows) {
            final d = DateTime(
              r.assignment.serviceDate.year,
              r.assignment.serviceDate.month,
              r.assignment.serviceDate.day,
            );
            byDate.putIfAbsent(d, () => []).add(r);
          }
          return RefreshIndicator(
            color: Sanctuary.auroraCyan,
            onRefresh: () => ref.read(syncServiceProvider).syncAll(),
            child: ListView.separated(
              padding: const EdgeInsets.all(10),
              // One extra item for leaders: the custom-date assigner.
              itemCount: dates.length + (isLeader ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                if (i >= dates.length) return const _CustomDateCard();
                return _ScheduleCard(
                  date: dates[i],
                  assignments: byDate[dates[i]] ?? [],
                  isFirst: i == 0,
                  isLeader: isLeader,
                );
              },
            ),
          );
        },
      ),
    );
  }

  List<DateTime> _nextFourSundays() {
    final now = DateTime.now();
    final dow = now.weekday;
    final daysToSunday = dow == 7 ? 0 : 7 - dow;
    var s = DateTime(now.year, now.month, now.day)
        .add(Duration(days: daysToSunday));
    final out = <DateTime>[];
    for (var i = 0; i < 4; i++) {
      out.add(s);
      s = s.add(const Duration(days: 7));
    }
    return out;
  }
}

class _ScheduleCard extends ConsumerStatefulWidget {
  const _ScheduleCard({
    required this.date,
    required this.assignments,
    required this.isFirst,
    required this.isLeader,
  });

  final DateTime date;
  final List<UpcomingAssignment> assignments;
  final bool isFirst;
  final bool isLeader;

  @override
  ConsumerState<_ScheduleCard> createState() => _ScheduleCardState();
}

class _ScheduleCardState extends ConsumerState<_ScheduleCard> {
  ProfileRow? _picked;
  String _role = _roles.first;
  bool _busy = false;

  Future<void> _add() async {
    final p = _picked;
    if (p == null || _busy) return;
    setState(() => _busy = true);
    final ok = await ref.read(syncServiceProvider).assignToSchedule(
          serviceDate: widget.date,
          userId: p.id,
          role: _role,
        );
    if (!mounted) return;
    if (ok) {
      setState(() => _picked = null);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not assign — check connection.')),
      );
    }
    setState(() => _busy = false);
  }

  Future<void> _remove(UpcomingAssignment a) async {
    final ok = await ref.read(syncServiceProvider).unassignSchedule(a.assignment.id);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not remove.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent =
        widget.isFirst ? Sanctuary.auroraCyan : Sanctuary.auroraViolet;
    return GlassCard(
      padding: const EdgeInsets.all(11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(widget.isFirst ? 'THIS SUNDAY' : 'UPCOMING',
                  style: Sanctuary.mono(fontSize: 10, color: accent)),
              const Spacer(),
              Text('${widget.assignments.length} assigned',
                  style: const TextStyle(
                      color: Sanctuary.muted, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 3),
          Text(DateFormat('EEEE, MMM d').format(widget.date),
              style: Sanctuary.display(fontSize: 17)),
          const SizedBox(height: 6),
          if (widget.assignments.isEmpty)
            const Text(
              'No assignments yet.',
              style: TextStyle(color: Sanctuary.muted, fontSize: 13),
            )
          else
            ...widget.assignments.map((a) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Sanctuary.auroraCyan.withValues(alpha: 0.1),
                          border: Border.all(
                              color: Sanctuary.auroraCyan
                                  .withValues(alpha: 0.25)),
                          borderRadius:
                              BorderRadius.circular(Sanctuary.radiusSm),
                        ),
                        child: Text(
                          a.assignment.role.toUpperCase(),
                          style: Sanctuary.mono(
                              fontSize: 9,
                              color: Sanctuary.auroraCyan,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          a.memberName,
                          style: const TextStyle(
                              color: Sanctuary.foreground, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.isLeader)
                        IconButton(
                          icon: const Icon(Icons.close,
                              size: 16, color: Sanctuary.muted),
                          tooltip: 'Remove',
                          onPressed: () => _remove(a),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                              minWidth: 28, minHeight: 28),
                        ),
                    ],
                  ),
                )),
          if (widget.isLeader) ...[
            const Divider(color: Sanctuary.hairline, height: 12),
            _AssignForm(
              picked: _picked,
              role: _role,
              busy: _busy,
              onMemberChanged: (p) => setState(() => _picked = p),
              onRoleChanged: (r) => setState(() => _role = r),
              onAdd: _add,
            ),
          ],
        ],
      ),
    );
  }
}

class _AssignForm extends ConsumerWidget {
  const _AssignForm({
    required this.picked,
    required this.role,
    required this.busy,
    required this.onMemberChanged,
    required this.onRoleChanged,
    required this.onAdd,
  });

  final ProfileRow? picked;
  final String role;
  final bool busy;
  final ValueChanged<ProfileRow?> onMemberChanged;
  final ValueChanged<String> onRoleChanged;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(allProfilesProvider);
    return profiles.when(
      loading: () => const SizedBox(
        height: 36,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (e, _) => Text('Members: $e',
          style: const TextStyle(color: Sanctuary.muted, fontSize: 12)),
      data: (members) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: picked?.id,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'Pick member',
                  ),
                  dropdownColor: Sanctuary.ink2,
                  items: members
                      .map((m) => DropdownMenuItem(
                            value: m.id,
                            child: Text(m.displayName,
                                style: const TextStyle(
                                    color: Sanctuary.foreground, fontSize: 13),
                                overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (id) {
                    final m = members.where((x) => x.id == id).firstOrNull;
                    onMemberChanged(m);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: role,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    isDense: true,
                  ),
                  dropdownColor: Sanctuary.ink2,
                  items: _roles
                      .map((r) => DropdownMenuItem(
                            value: r,
                            child: Text(r,
                                style: Sanctuary.mono(
                                    fontSize: 12,
                                    color: Sanctuary.foreground,
                                    letterSpacing: 0)),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) onRoleChanged(v);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FilledButton.icon(
            onPressed: picked == null || busy ? null : onAdd,
            style: FilledButton.styleFrom(
              backgroundColor: Sanctuary.auroraCyan,
              foregroundColor: Sanctuary.ink0,
              minimumSize: const Size(0, 40),
            ),
            icon: busy
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Sanctuary.ink0),
                  )
                : const Icon(Icons.add, size: 18),
            label: Text(busy ? 'Adding…' : 'Add member'),
          ),
        ],
      ),
    );
  }
}

/// Leader-only assigner for an arbitrary date (mirrors the web "Custom date"
/// section) — useful for special services that aren't one of the next four
/// Sundays.
class _CustomDateCard extends ConsumerStatefulWidget {
  const _CustomDateCard();

  @override
  ConsumerState<_CustomDateCard> createState() => _CustomDateCardState();
}

class _CustomDateCardState extends ConsumerState<_CustomDateCard> {
  DateTime? _date;
  ProfileRow? _picked;
  String _role = _roles.first;
  bool _busy = false;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _add() async {
    final d = _date;
    final p = _picked;
    if (d == null || p == null || _busy) return;
    setState(() => _busy = true);
    final ok = await ref.read(syncServiceProvider).assignToSchedule(
          serviceDate: d,
          userId: p.id,
          role: _role,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      setState(() {
        _picked = null;
        _date = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Assignment added.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not assign — check connection.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profiles = ref.watch(allProfilesProvider);
    return GlassCard(
      padding: const EdgeInsets.all(11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('CUSTOM DATE',
              style:
                  Sanctuary.mono(fontSize: 10, color: Sanctuary.auroraViolet)),
          const SizedBox(height: 8),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(Sanctuary.radiusMd),
            child: InputDecorator(
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.calendar_today,
                    size: 16, color: Sanctuary.muted),
              ),
              child: Text(
                _date == null
                    ? 'Pick a date'
                    : DateFormat('EEE, MMM d, yyyy').format(_date!),
                style: TextStyle(
                  color:
                      _date == null ? Sanctuary.muted : Sanctuary.foreground,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          profiles.when(
            loading: () => const SizedBox(
              height: 36,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (e, _) => Text('Members: $e',
                style: const TextStyle(color: Sanctuary.muted, fontSize: 12)),
            data: (members) => Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _picked?.id,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: 'Pick member',
                    ),
                    dropdownColor: Sanctuary.ink2,
                    items: members
                        .map((m) => DropdownMenuItem(
                              value: m.id,
                              child: Text(m.displayName,
                                  style: const TextStyle(
                                      color: Sanctuary.foreground,
                                      fontSize: 13),
                                  overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (id) {
                      final m =
                          members.where((x) => x.id == id).firstOrNull;
                      setState(() => _picked = m);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _role,
                    isExpanded: true,
                    decoration: const InputDecoration(isDense: true),
                    dropdownColor: Sanctuary.ink2,
                    items: _roles
                        .map((r) => DropdownMenuItem(
                              value: r,
                              child: Text(r,
                                  style: Sanctuary.mono(
                                      fontSize: 12,
                                      color: Sanctuary.foreground,
                                      letterSpacing: 0)),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _role = v);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          FilledButton.icon(
            onPressed:
                (_date == null || _picked == null || _busy) ? null : _add,
            style: FilledButton.styleFrom(
              backgroundColor: Sanctuary.auroraViolet,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 40),
            ),
            icon: _busy
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.add, size: 18),
            label: const Text('Add assignment'),
          ),
        ],
      ),
    );
  }
}
