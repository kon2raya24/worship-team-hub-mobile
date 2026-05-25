import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_provider.dart';
import '../features/auth/ui/login_screen.dart';
import '../features/home/ui/home_screen.dart';
import '../features/songs/ui/songs_list_screen.dart';
import '../features/songs/ui/song_detail_screen.dart';
import '../features/setlists/ui/setlists_list_screen.dart';
import '../features/setlists/ui/setlist_detail_screen.dart';
import '../features/schedule/ui/schedule_screen.dart';
import 'supabase_client.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: GoRouterRefreshStream(
      supabase.auth.onAuthStateChange,
    ),
    redirect: (context, state) {
      final signedIn = ref.read(isSignedInProvider);
      final goingToLogin = state.matchedLocation == '/login';
      if (!signedIn && !goingToLogin) return '/login';
      if (signedIn && goingToLogin) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
      GoRoute(path: '/songs', builder: (_, __) => const SongsListScreen()),
      GoRoute(
        path: '/songs/:id',
        builder: (_, state) => SongDetailScreen(
          songId: state.pathParameters['id']!,
          targetKey: state.uri.queryParameters['key'],
        ),
      ),
      GoRoute(
        path: '/setlists',
        builder: (_, __) => const SetlistsListScreen(),
      ),
      GoRoute(
        path: '/setlists/:id',
        builder: (_, state) =>
            SetlistDetailScreen(setlistId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/schedule',
        builder: (_, __) => const ScheduleScreen(),
      ),
    ],
  );
});

/// Bridges a Stream into a Listenable so GoRouter can re-evaluate redirects
/// whenever the auth state changes.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _sub = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
