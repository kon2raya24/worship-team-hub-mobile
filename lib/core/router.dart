import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_provider.dart';
import '../features/auth/ui/login_screen.dart';
import '../features/auth/ui/signup_screen.dart';
import '../features/auth/ui/forgot_password_screen.dart';
import '../features/auth/ui/mfa_challenge_screen.dart';
import '../features/home/ui/home_screen.dart';
import '../features/more/ui/more_screen.dart';
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
import '../features/games/ui/nashville_game_screen.dart';
import '../features/games/ui/capo_game_screen.dart';
import '../features/games/ui/intervals_game_screen.dart';
import '../features/games/ui/chord_tones_game_screen.dart';
import '../features/games/ui/relative_game_screen.dart';
import '../features/settings/ui/settings_screen.dart';
import '../features/team/ui/team_screen.dart';
import 'home_shell.dart';
import 'supabase_client.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // One notifier that bumps on either Supabase auth events *or* Riverpod
  // changes to `effectiveSignedInProvider`. Without the Riverpod half, the
  // router doesn't re-evaluate when the offline-mode flag flips, and the
  // login screens have to push `context.go('/')` manually — a workaround
  // that breaks the moment any other code path mutates the flag.
  final refresh = _RouterRefresh();
  final authSub =
      supabase.auth.onAuthStateChange.listen((_) => refresh.bump());
  ref.listen<bool>(effectiveSignedInProvider, (_, __) => refresh.bump());
  ref.listen<bool>(mfaPendingProvider, (_, __) => refresh.bump());
  ref.onDispose(() {
    authSub.cancel();
    refresh.dispose();
  });

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final signedIn = ref.read(effectiveSignedInProvider);
      final loc = state.matchedLocation;
      const unauthOk = {'/login', '/signup', '/forgot-password'};

      if (!signedIn) {
        return unauthOk.contains(loc) ? null : '/login';
      }
      // Second factor still owed → hold the user on /mfa until they verify.
      if (ref.read(mfaPendingProvider)) {
        return loc == '/mfa' ? null : '/mfa';
      }
      if (loc == '/mfa' || loc == '/login') return '/';
      return null;
    },
    routes: [
      // Auth — outside the shell (no bottom nav).
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, __) => const SignupScreen()),
      GoRoute(
        path: '/forgot-password',
        builder: (_, __) => const ForgotPasswordScreen(),
      ),
      GoRoute(path: '/mfa', builder: (_, __) => const MfaChallengeScreen()),

      // Everything else runs inside the bottom-nav shell. Each branch keeps
      // its own nav stack so e.g. opening a song detail then tapping the
      // Setlists tab lets you come back to that same song detail.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navShell) => HomeShell(navShell: navShell),
        branches: [
          // 0 · Home
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
            ],
          ),

          // 1 · Songs
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/songs',
                builder: (_, __) => const SongsListScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (_, __) => const SongComposeScreen(),
                  ),
                  GoRoute(
                    path: 'import',
                    builder: (_, __) => const SongImportScreen(),
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (_, state) => SongDetailScreen(
                      songId: state.pathParameters['id']!,
                      targetKey: state.uri.queryParameters['key'],
                    ),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        builder: (_, state) => SongComposeScreen(
                            songId: state.pathParameters['id']!),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          // 2 · Setlists
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/setlists',
                builder: (_, __) => const SetlistsListScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (_, __) => const SetlistComposeScreen(),
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (_, state) => SetlistDetailScreen(
                        setlistId: state.pathParameters['id']!),
                    routes: [
                      GoRoute(
                        path: 'add-song',
                        builder: (_, state) => SetlistAddSongScreen(
                            setlistId: state.pathParameters['id']!),
                      ),
                      GoRoute(
                        path: 'edit',
                        builder: (_, state) => SetlistComposeScreen(
                            setlistId: state.pathParameters['id']!),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          // 3 · Schedule
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/schedule',
                builder: (_, __) => const ScheduleScreen(),
              ),
            ],
          ),

          // 4 · More (Devotions / Prayer / Announcements / Games / Team /
          //          Settings — all nested here so the More tab stays
          //          selected while you're on any of them)
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/more', builder: (_, __) => const MoreScreen()),
              GoRoute(
                path: '/devotions',
                builder: (_, __) => const DevotionsListScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (_, __) => const DevotionComposeScreen(),
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (_, state) => DevotionDetailScreen(
                        devotionId: state.pathParameters['id']!),
                  ),
                ],
              ),
              GoRoute(
                path: '/prayer',
                builder: (_, __) => const PrayerScreen(),
              ),
              GoRoute(
                path: '/announcements',
                builder: (_, __) => const AnnouncementsScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (_, __) => const AnnouncementComposeScreen(),
                  ),
                ],
              ),
              GoRoute(
                path: '/games',
                builder: (_, __) => const GamesIndexScreen(),
                routes: [
                  GoRoute(
                    path: 'transpose',
                    builder: (_, __) => const TransposeGameScreen(),
                  ),
                  GoRoute(
                    path: 'keys',
                    builder: (_, __) => const KeysGameScreen(),
                  ),
                  GoRoute(
                    path: 'bpm',
                    builder: (_, __) => const BpmGameScreen(),
                  ),
                  GoRoute(
                    path: 'nashville',
                    builder: (_, __) => const NashvilleGameScreen(),
                  ),
                  GoRoute(
                    path: 'capo',
                    builder: (_, __) => const CapoGameScreen(),
                  ),
                  GoRoute(
                    path: 'intervals',
                    builder: (_, __) => const IntervalsGameScreen(),
                  ),
                  GoRoute(
                    path: 'chord-tones',
                    builder: (_, __) => const ChordTonesGameScreen(),
                  ),
                  GoRoute(
                    path: 'relative',
                    builder: (_, __) => const RelativeGameScreen(),
                  ),
                ],
              ),
              GoRoute(path: '/team', builder: (_, __) => const TeamScreen()),
              GoRoute(
                path: '/settings',
                builder: (_, __) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

/// Plain ChangeNotifier that exposes `notifyListeners()` so the router
/// provider can poke it from both the Supabase auth stream and a Riverpod
/// listener on `effectiveSignedInProvider`.
class _RouterRefresh extends ChangeNotifier {
  void bump() => notifyListeners();
}
