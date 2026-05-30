import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/auth_provider.dart';
import 'sync_service.dart';

/// Streams the device's current connectivity. A non-empty list of results
/// without [ConnectivityResult.none] means we're online.
///
/// `onConnectivityChanged` only emits when state *changes*, so we seed the
/// stream with `checkConnectivity()` first. Without this the stream is
/// pending on cold start and consumers can't tell online from offline.
final connectivityProvider = StreamProvider<List<ConnectivityResult>>((ref) async* {
  final c = Connectivity();
  try {
    yield await c.checkConnectivity();
  } catch (_) {
    // If the initial probe fails, fall through to the change stream.
  }
  yield* c.onConnectivityChanged;
});

bool isOnline(List<ConnectivityResult> results) {
  if (results.isEmpty) return false;
  return results.any((r) => r != ConnectivityResult.none);
}

/// Watches connectivity and triggers a sync whenever the device transitions
/// from offline → online. Wire this up once at the app shell (e.g. inside
/// HomeScreen) — `ref.listen` makes it side-effect-only.
void wireAutoSync(WidgetRef ref) {
  ref.listen<AsyncValue<List<ConnectivityResult>>>(connectivityProvider,
      (prev, next) {
    final prevOnline = prev?.value != null && isOnline(prev!.value!);
    final nowOnline = next.value != null && isOnline(next.value!);
    if (!prevOnline && nowOnline) {
      // Restore a real session if we were stuck in offline mode, then sync.
      // ignore: discarded_futures
      recoverFromOfflineMode(ref)
          .then((_) => ref.read(syncServiceProvider).syncAll());
    }
  });
}
