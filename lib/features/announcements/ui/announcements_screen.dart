import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../../data/db/app_db.dart';
import '../../../data/sync/providers.dart';
import '../../../data/sync/sync_service.dart';
import '../../auth/auth_provider.dart';

class AnnouncementsScreen extends ConsumerWidget {
  const AnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final feed = ref.watch(announcementsStreamProvider);
    final isLeader = ref.watch(isLeaderProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 20),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: const Text('Announcements'),
      ),
      floatingActionButton: isLeader
          ? FloatingActionButton.extended(
              backgroundColor: cs.primary,
              foregroundColor: Colors.white,
              onPressed: () => context.push('/announcements/new'),
              icon: const Icon(Icons.add),
              label: const Text('New'),
            )
          : null,
      body: feed.when(
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
                        icon: Icons.campaign_outlined,
                        title: 'No announcements yet',
                        subtitle: 'Pull down to sync.',
                      ),
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _Card(a: list[i], isLeader: isLeader),
                ),
        ),
      ),
    );
  }
}

class _Card extends ConsumerWidget {
  const _Card({required this.a, required this.isLeader});
  final AnnouncementRow a;
  final bool isLeader;

  Future<void> _togglePin(WidgetRef ref, BuildContext context) async {
    final ok = await ref
        .read(syncServiceProvider)
        .togglePinAnnouncement(a.id, !a.pinned);
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update pin.')),
      );
    }
  }

  Future<void> _confirmDelete(WidgetRef ref, BuildContext context) async {
    final cs = Theme.of(context).colorScheme;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cs.surfaceContainer,
        title: const Text('Delete announcement?'),
        content: Text('"${a.title}" will be removed for everyone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: cs.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final deleted =
        await ref.read(syncServiceProvider).deleteAnnouncement(a.id);
    if (!context.mounted) return;
    if (!deleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delete failed.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (a.pinned) ...[
                const Icon(Icons.push_pin,
                    size: 14, color: Sanctuary.auroraAmber),
                const SizedBox(width: 4),
                Text('PINNED',
                    style: Sanctuary.mono(
                        fontSize: 9,
                        color: Sanctuary.auroraAmber,
                        fontWeight: FontWeight.w700)),
                const SizedBox(width: 10),
              ],
              Text(DateFormat.MMMd().add_jm().format(a.createdAt),
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11)),
              const Spacer(),
              if (isLeader)
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_horiz,
                      size: 18, color: cs.onSurfaceVariant),
                  color: cs.surfaceContainer,
                  onSelected: (v) {
                    if (v == 'pin') _togglePin(ref, context);
                    if (v == 'delete') _confirmDelete(ref, context);
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'pin',
                      child: Row(
                        children: [
                          Icon(a.pinned
                              ? Icons.push_pin_outlined
                              : Icons.push_pin),
                          const SizedBox(width: 8),
                          Text(a.pinned ? 'Unpin' : 'Pin to top'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: cs.error),
                          const SizedBox(width: 8),
                          Text('Delete',
                              style: TextStyle(color: cs.error)),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(a.title,
              style: Sanctuary.display(
                  fontSize: 17, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          MarkdownBody(
            data: a.body,
            styleSheet: MarkdownStyleSheet(
              p: TextStyle(
                  color: cs.onSurface, fontSize: 14, height: 1.5),
              a: TextStyle(
                  color: cs.secondary,
                  decoration: TextDecoration.underline),
            ),
          ),
        ],
      ),
    );
  }
}
