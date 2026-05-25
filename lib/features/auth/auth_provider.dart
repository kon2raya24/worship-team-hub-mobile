import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_client.dart';
import '../../data/db/app_db.dart';
import '../../data/sync/sync_service.dart';

/// Stream of auth state changes — emits whenever the user signs in / out.
final authStateProvider = StreamProvider<AuthState>((ref) {
  return supabase.auth.onAuthStateChange;
});

/// Current session (null when signed out). Reactive to auth state changes.
final sessionProvider = Provider<Session?>((ref) {
  ref.watch(authStateProvider);
  return supabase.auth.currentSession;
});

/// True when a real Supabase session is active.
final isSignedInProvider = Provider<bool>((ref) {
  return ref.watch(sessionProvider) != null;
});

/// Offline mode: set true when biometric sign-in succeeded but the network
/// call to Supabase failed. The router treats this as "signed in" so the
/// user can browse cached Drift data. Writes that hit Supabase will still
/// fail naturally — code paths that need a real user check
/// supabase.auth.currentUser independently.
final offlineModeProvider = StateProvider<bool>((ref) => false);

/// Combined "user can see the home screen" check.
final effectiveSignedInProvider = Provider<bool>((ref) {
  if (ref.watch(isSignedInProvider)) return true;
  return ref.watch(offlineModeProvider);
});

/// The email used for the active session, falling back to the offline
/// credentials when in offline mode.
final activeEmailProvider = Provider<String?>((ref) {
  final session = ref.watch(sessionProvider);
  if (session?.user.email != null) return session!.user.email;
  // In offline mode the email is read from secure storage by the screens that
  // need it (BiometricService.readCredentials); we don't expose it here so
  // we don't have to bind the provider to async storage.
  return null;
});

/// Looks up the signed-in user's profile (display name + role) from the
/// local Drift cache. Used to gate leader-only UI (compose buttons, edit
/// actions). Returns null if no session or no profile row yet synced.
final currentProfileProvider = FutureProvider<ProfileRow?>((ref) async {
  ref.watch(authStateProvider); // re-fire on sign-out
  final id = supabase.auth.currentUser?.id;
  if (id == null) return null;
  final db = ref.watch(appDbProvider);
  return db.getProfile(id);
});

final isLeaderProvider = Provider<bool>((ref) {
  final p = ref.watch(currentProfileProvider).value;
  return p?.role == 'leader';
});
