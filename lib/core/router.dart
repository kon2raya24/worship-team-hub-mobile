import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_provider.dart';
import '../features/auth/ui/login_screen.dart';
import '../features/auth/ui/signup_screen.dart';
import '../features/auth/ui/forgot_password_screen.dart';
import '../features/home/ui/home_screen.dart';
import '../features/songs/ui/songs_list_screen.dart';
import '../features/songs/ui/song_detail_screen.dart';
import '../features/setlists/ui/setlists_list_screen.dart';
import '../features/setlists/ui/setlist_detail_screen.dart';
import '../features/setlists/ui/setlist_compose_screen.dart';
import '../features/setlists/ui/setlist_add_song_screen.dart';
import '../features/schedule/ui/schedule_screen.dart';
import '../features/devotions/ui/devotions_list_screen.dart';
import '../features/devotions/ui/devotion_detail_screen.dart';
import '../features/devotions/ui/devotion_compose_screen.dart';
import '../features/songs/ui/song_compose_screen.dart';
import '../features/songs/ui/song_import_screen.dart';
import '../features/prayer/ui/prayer_screen.dart';
import '../features/announcements/ui/announcements_screen.dart';
import '../features/announcements/ui/announcement_compose_screen.dart';
import '../features/games/ui/games_index_screen.dart';
import '../features/games/ui/transpose_game_screen.dart';
import '../features/games/ui/keys_game_screen.dart';
import '../features/games/ui/bpm_game_screen.dart';
import '../features/settings/ui/settings_screen.dart';
import '../features/team/ui/team_screen.dart';
import 'supabase_client.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: GoRouterRefreshStream(
      supabase.auth.onAuthStateChange,
    ),
    redirect: (context, state) {
      final signedIn = ref.read(effectiveSignedInProvider);
      final loc = state.matchedLocation;
      const unauthOk = {'/login', '/signup', '/forgot-password'};

      if (!signedIn) {
        return unauthOk.contains(loc) ? null : '/login';
      }
      if (loc == '/login') return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, __) => const SignupScreen()),
      GoRoute(
        path: '/forgot-password',
        builder: (_, __) => const ForgotPasswordScreen(),
      ),
      GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
      GoRoute(path: '/songs', builder: (_, __) => const SongsListScreen()),
      GoRoute(
        path: '/songs/new',
        builder: (_, __) => const SongComposeScreen(),
      ),
      GoRoute(
        path: '/songs/import',
        builder: (_, __) => const SongImportScreen(),
      ),
      GoRoute(
        path: '/songs/:id',
        builder: (_, state) => SongDetailScreen(
          songId: state.pathParameters['id']!,
          targetKey: state.uri.queryParameters['key'],
        ),
      ),
      GoRoute(
        path: '/songs/:id/edit',
        builder: (_, state) =>
            SongComposeScreen(songId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/setlists',
        builder: (_, __) => const SetlistsListScreen(),
      ),
      GoRoute(
        path: '/setlists/new',
        builder: (_, __) => const SetlistComposeScreen(),
      ),
      GoRoute(
        path: '/setlists/:id',
        builder: (_, state) =>
            SetlistDetailScreen(setlistId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/setlists/:id/add-song',
        builder: (_, state) =>
            SetlistAddSongScreen(setlistId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/schedule',
        builder: (_, __) => const ScheduleScreen(),
      ),
      GoRoute(
        path: '/devotions',
        builder: (_, __) => const DevotionsListScreen(),
      ),
      GoRoute(
        path: '/devotions/new',
        builder: (_, __) => const DevotionComposeScreen(),
      ),
      GoRoute(
        path: '/devotions/:id',
        builder: (_, state) =>
            DevotionDetailScreen(devotionId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/prayer',
        builder: (_, __) => const PrayerScreen(),
      ),
      GoRoute(
        path: '/announcements',
        builder: (_, __) => const AnnouncementsScreen(),
      ),
      GoRoute(
        path: '/announcements/new',
        builder: (_, __) => const AnnouncementComposeScreen(),
      ),
      GoRoute(
        path: '/games',
        builder: (_, __) => const GamesIndexScreen(),
      ),
      GoRoute(
        path: '/games/transpose',
        builder: (_, __) => const TransposeGameScreen(),
      ),
      GoRoute(
        path: '/games/keys',
        builder: (_, __) => const KeysGameScreen(),
      ),
      GoRoute(
        path: '/games/bpm',
        builder: (_, __) => const BpmGameScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (_, __) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/team',
        builder: (_, __) => const TeamScreen(),
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
