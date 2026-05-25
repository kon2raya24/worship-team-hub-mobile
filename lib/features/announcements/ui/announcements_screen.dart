import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../../data/db/app_db.dart';
import '../../../data/sync/providers.dart';
import '../../../data/sync/sync_service.dart';

class AnnouncementsScreen extends ConsumerWidget {
  const AnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(announcementsStreamProvider);
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
      body: feed.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Failed to load.\n$e',
              style: const TextStyle(color: Sanctuary.muted)),
        ),
        data: (list) => RefreshIndicator(
          color: Sanctuary.auroraCyan,
          onRefresh: () => ref.read(syncServiceProvider).syncAll(),
          child: list.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 120),
                    Center(
                      child: Text('No announcements yet.\nPull to sync.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Sanctuary.muted)),
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _Card(a: list[i]),
                ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.a});
  final AnnouncementRow a;

  @override
  Widget build(BuildContext context) {
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
                  style: const TextStyle(color: Sanctuary.muted, fontSize: 11)),
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
              p: const TextStyle(
                  color: Sanctuary.foreground, fontSize: 14, height: 1.5),
              a: const TextStyle(
                  color: Sanctuary.auroraCyan,
                  decoration: TextDecoration.underline),
            ),
          ),
        ],
      ),
    );
  }
}
