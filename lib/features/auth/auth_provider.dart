import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_client.dart';

/// Stream of auth state changes — emits whenever the user signs in / out.
/// Use `ref.watch(authStateProvider)` to react to session changes.
final authStateProvider = StreamProvider<AuthState>((ref) {
  return supabase.auth.onAuthStateChange;
});

/// Current session (null when signed out). Reactive to auth state changes.
final sessionProvider = Provider<Session?>((ref) {
  ref.watch(authStateProvider);
  return supabase.auth.currentSession;
});

/// True when a user is signed in. Cheap to watch.
final isSignedInProvider = Provider<bool>((ref) {
  return ref.watch(sessionProvider) != null;
});
