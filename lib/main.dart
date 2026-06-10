import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/env.dart';
import 'features/auth/biometric_service.dart' show sharedPrefsProvider;

/// Background isolate handler. Notification messages are displayed by the OS
/// automatically, so there's nothing to do here — but FCM requires a
/// registered top-level handler to deliver background messages at all.
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
  } catch (_) {
    // No Firebase config on this build (or no Play services) — push stays off;
    // the rest of the app runs normally.
  }

  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
    debug: false,
  );

  // Warm up the low-latency audio engine (metronome + backing track) at launch
  // so the first Start has no init lag, and — critically — so any engine-init
  // failure surfaces in the logs immediately instead of silently producing no
  // sound on device. Wrapped so a failure here never blocks app startup.
  try {
    if (!SoLoud.instance.isInitialized) await SoLoud.instance.init();
    debugPrint('[audio] SoLoud init ok — volume=${SoLoud.instance.getGlobalVolume()} '
        'devices=${SoLoud.instance.listPlaybackDevices().map((d) => d.name).toList()}');
  } catch (e, st) {
    debugPrint('[audio] SoLoud init FAILED: $e\n$st');
  }

  // Preload prefs so the saved theme (and biometric settings) resolve
  // synchronously on the first frame instead of flashing the default.
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [sharedPrefsProvider.overrideWith((ref) => prefs)],
      child: const WorshipApp(),
    ),
  );
}
