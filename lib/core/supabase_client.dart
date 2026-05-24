import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin accessor for the global Supabase client. Initialized in main().
SupabaseClient get supabase => Supabase.instance.client;

/// Convenience: current auth user, null if signed out.
User? get currentUser => supabase.auth.currentUser;
