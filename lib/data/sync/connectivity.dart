import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'sync_service.dart';

/// Streams the device's current connectivity. A non-empty list of results
/// without [ConnectivityResult.none] means we're online.
final connectivityProvider = StreamProvider<List<ConnectivityResult>>((ref) {
  final c = Connectivity();
  return c.onConnectivityChanged;
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
      // ignore: discarded_futures
      ref.read(syncServiceProvider).syncAll();
    }
  });
}
