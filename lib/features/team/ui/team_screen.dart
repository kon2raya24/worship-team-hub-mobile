import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/supabase_client.dart';
import '../../../data/db/app_db.dart';
import '../../../data/sync/providers.dart';
import '../../../data/sync/sync_service.dart';
import '../../auth/auth_provider.dart';

class TeamScreen extends ConsumerWidget {
  const TeamScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(allProfilesProvider);
    final isLeader = ref.watch(isLeaderProvider);
    final me = supabase.auth.currentUser?.id;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 20),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: const Text('Team'),
      ),
      body: profiles.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Failed to load team.\n$e',
              style: const TextStyle(color: Sanctuary.muted)),
        ),
        data: (list) => RefreshIndicator(
          color: Sanctuary.auroraCyan,
          onRefresh: () async {
            await ref.read(syncServiceProvider).syncAll();
            ref.invalidate(allProfilesProvider);
          },
          child: list.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 120),
                    Center(
                      child: EmptyState(
                        icon: Icons.groups_outlined,
                        title: 'No members yet',
                        subtitle: 'Pull down to sync.',
                      ),
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _MemberCard(
                    p: list[i],
                    isLeader: isLeader,
                    isMe: list[i].id == me,
                  ),
                ),
        ),
      ),
    );
  }
}

class _MemberCard extends ConsumerWidget {
  const _MemberCard({
    required this.p,
    required this.isLeader,
    required this.isMe,
  });

  final ProfileRow p;
  final bool isLeader;
  final bool isMe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLeaderRole = p.role == 'leader';
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isLeaderRole
                  ? Sanctuary.auroraViolet.withValues(alpha: 0.18)
                  : Sanctuary.glass1,
              border: Border.all(
                color: isLeaderRole
                    ? Sanctuary.auroraViolet.withValues(alpha: 0.45)
                    : Sanctuary.hairline,
              ),
              borderRadius: BorderRadius.circular(Sanctuary.radiusMd),
            ),
            alignment: Alignment.center,
            child: Text(
              p.displayName.isEmpty ? '?' : p.displayName[0].toUpperCase(),
              style: Sanctuary.display(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isLeaderRole
                    ? Sanctuary.auroraViolet
                    : Sanctuary.foreground,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        p.displayName,
                        style: Sanctuary.display(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Sanctuary.glass1,
                          border: Border.all(color: Sanctuary.hairline),
                          borderRadius:
                              BorderRadius.circular(Sanctuary.radiusSm),
                        ),
                        child: Text('YOU',
                            style: Sanctuary.mono(
                                fontSize: 9, color: Sanctuary.muted)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: isLeaderRole
                            ? Sanctuary.auroraViolet.withValues(alpha: 0.12)
                            : Sanctuary.auroraCyan.withValues(alpha: 0.08),
                        border: Border.all(
                            color: isLeaderRole
                                ? Sanctuary.auroraViolet
                                    .withValues(alpha: 0.35)
                                : Sanctuary.auroraCyan
                                    .withValues(alpha: 0.25)),
                        borderRadius:
                            BorderRadius.circular(Sanctuary.radiusSm),
                      ),
                      child: Text(
                        // Mask the permission role: DB stores leader/member,
                        // but we surface "Editor"/"Member" like the web app.
                        isLeaderRole ? 'EDITOR' : 'MEMBER',
                        style: Sanctuary.mono(
                          fontSize: 9,
                          color: isLeaderRole
                              ? Sanctuary.auroraViolet
                              : Sanctuary.auroraCyan,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isLeader && !isMe)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_horiz,
                  size: 18, color: Sanctuary.muted),
              color: Sanctuary.ink2,
              onSelected: (v) async {
                final newRole = isLeaderRole ? 'member' : 'leader';
                final ok = await ref
                    .read(syncServiceProvider)
                    .setMemberRole(p.id, newRole);
                if (!context.mounted) return;
                ref.invalidate(allProfilesProvider);
                if (!ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Role change failed.')),
                  );
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'toggle',
                  child: Row(children: [
                    Icon(isLeaderRole
                        ? Icons.person_outline
                        : Icons.shield_outlined),
                    const SizedBox(width: 8),
                    Text(isLeaderRole ? 'Make member' : 'Make editor'),
                  ]),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
