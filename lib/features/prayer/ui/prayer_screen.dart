import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../../core/supabase_client.dart';
import '../../../data/db/app_db.dart';
import '../../../data/sync/providers.dart';
import '../../../data/sync/sync_service.dart';
import '../../auth/auth_provider.dart';

class PrayerScreen extends ConsumerStatefulWidget {
  const PrayerScreen({super.key});

  @override
  ConsumerState<PrayerScreen> createState() => _PrayerScreenState();
}

class _PrayerScreenState extends ConsumerState<PrayerScreen> {
  final _controller = TextEditingController();
  bool _posting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final body = _controller.text.trim();
    if (body.isEmpty || _posting) return;
    setState(() => _posting = true);
    final ok = await ref.read(syncServiceProvider).postPrayerRequest(body);
    if (!mounted) return;
    setState(() => _posting = false);
    if (ok) {
      _controller.clear();
      FocusScope.of(context).unfocus();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not post — check your connection.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final prayers = ref.watch(prayerRequestsStreamProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 20),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: const Text('Prayer requests'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: prayers.when(
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
                                icon: Icons.volunteer_activism_outlined,
                                title: 'No prayer requests yet',
                                subtitle: 'Be the first to share.',
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: list.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) => _Card(p: list[i]),
                        ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: GlassCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText: 'Share a request…',
                          border: InputBorder.none,
                          filled: false,
                          contentPadding: EdgeInsets.symmetric(vertical: 6),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: _posting
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: cs.secondary),
                            )
                          : Icon(Icons.send, color: cs.secondary),
                      onPressed: _posting ? null : _submit,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends ConsumerWidget {
  const _Card({required this.p});
  final PrayerRequestRow p;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final successColor = isDark ? Sanctuary.success : Sanctuary.lightSuccess;
    final author = (p.authorName ?? '').isEmpty ? 'Anonymous' : p.authorName!;
    final isLeader = ref.watch(isLeaderProvider);
    final isAuthor = supabase.auth.currentUser?.id == p.authorId;
    final canManage = isLeader || isAuthor;
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(author,
                  style: Sanctuary.display(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Text(DateFormat.MMMd().add_jm().format(p.createdAt),
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11)),
              const Spacer(),
              if (p.isAnswered)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: successColor.withValues(alpha: 0.15),
                    border: Border.all(
                        color: successColor.withValues(alpha: 0.4)),
                    borderRadius: BorderRadius.circular(Sanctuary.radiusSm),
                  ),
                  child: Text('ANSWERED',
                      style: Sanctuary.mono(
                          fontSize: 9,
                          color: successColor,
                          fontWeight: FontWeight.w700)),
                ),
              if (canManage)
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_horiz,
                      size: 18, color: cs.onSurfaceVariant),
                  color: cs.surfaceContainer,
                  onSelected: (v) async {
                    if (v == 'answered') {
                      await ref
                          .read(syncServiceProvider)
                          .setPrayerAnswered(p.id, !p.isAnswered);
                    } else if (v == 'delete') {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: cs.surfaceContainer,
                          title: const Text('Delete request?'),
                          content: const Text('This can\'t be undone.'),
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
                      if (ok == true) {
                        await ref
                            .read(syncServiceProvider)
                            .deletePrayerRequest(p.id);
                      }
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'answered',
                      child: Row(children: [
                        Icon(p.isAnswered
                            ? Icons.refresh
                            : Icons.check_circle_outline),
                        const SizedBox(width: 8),
                        Text(p.isAnswered ? 'Mark unanswered' : 'Mark answered'),
                      ]),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        Icon(Icons.delete_outline, color: cs.error),
                        const SizedBox(width: 8),
                        Text('Delete',
                            style: TextStyle(color: cs.error)),
                      ]),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(p.body,
              style: TextStyle(
                  color: cs.onSurface, fontSize: 14, height: 1.5)),
        ],
      ),
    );
  }
}
