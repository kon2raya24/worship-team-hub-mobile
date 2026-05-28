import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_client.dart';
import '../../data/db/app_db.dart';
import '../../data/sync/sync_service.dart';
import 'biometric_service.dart';

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

/// True when the signed-in session still owes its second factor: the account
/// has a verified TOTP factor but the session is only AAL1. The router holds
/// the user on /mfa until they enter a code. Set by the login flow after an
/// online password sign-in; cleared by the MFA screen on success / sign-out.
/// (Offline + biometric sign-in skip this — there's no network to verify a
/// TOTP code, and the device biometric already gates that path.)
final mfaPendingProvider = StateProvider<bool>((ref) => false);

/// The email used for the active session, falling back to the offline
/// credentials when in offline mode.
final activeEmailProvider = FutureProvider<String?>((ref) async {
  final session = ref.watch(sessionProvider);
  if (session?.user.email != null) return session!.user.email;
  // Offline: read the email we cached on the last successful sign-in.
  ref.watch(offlineModeProvider);
  final svc = ref.watch(biometricServiceProvider);
  if (svc == null) return null;
  final creds = await svc.readCredentials();
  return creds?.email;
});

/// Looks up the signed-in user's profile (display name + role) from the
/// local Drift cache. Used to gate leader-only UI (compose buttons, edit
/// actions). Returns null if no session or no profile row yet synced.
///
/// Offline path: when there's no live Supabase session, we fall back to the
/// user id stashed in secure storage on the last successful sign-in so the
/// leader UI keeps working and the home screen can greet the user by name.
final currentProfileProvider = FutureProvider<ProfileRow?>((ref) async {
  ref.watch(authStateProvider); // re-fire on sign-out
  ref.watch(offlineModeProvider); // re-fire on offline-mode toggle
  String? id = supabase.auth.currentUser?.id;
  if (id == null) {
    final svc = ref.watch(biometricServiceProvider);
    id = await svc?.readUserId();
  }
  if (id == null) return null;
  final db = ref.watch(appDbProvider);
  return db.getProfile(id);
});

/// Leader gate for add/edit UI. Derived from [currentProfileProvider] but
/// deliberately "sticky": it only changes when the profile *resolves* to a
/// value. While the profile is momentarily reloading — Supabase fires
/// onAuthStateChange on every token refresh / app resume, which re-runs
/// currentProfileProvider — we keep the last known answer. Without this the
/// leader-only buttons (add/edit) blink out during those transient reloads.
final isLeaderProvider = NotifierProvider<IsLeaderNotifier, bool>(
  IsLeaderNotifier.new,
);

class IsLeaderNotifier extends Notifier<bool> {
  bool _last = false;

  @override
  bool build() {
    final async = ref.watch(currentProfileProvider);
    // hasValue is true for resolved data *and* for a reload that preserved
    // the previous value; false for a first/empty load or a bare error — in
    // which case we fall through and keep [_last].
    if (async.hasValue) {
      _last = async.value?.role == 'leader';
    }
    return _last;
  }
}
