import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/supabase_client.dart';

const _kBiometricEnabledKey = 'biometric_enabled';

/// Wraps local_auth + a "biometric enabled" preference. Auth state itself
/// stays in supabase_flutter — this service only decides whether to gate
/// the home screen with a fingerprint prompt at app launch.
class BiometricService {
  BiometricService(this._prefs);

  final SharedPreferences _prefs;
  final LocalAuthentication _auth = LocalAuthentication();

  /// Hardware + OS support check. Doesn't mean the user has enrolled a
  /// fingerprint/face — just that this device can in principle.
  Future<bool> canCheckBiometrics() async {
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) return false;
      return await _auth.canCheckBiometrics;
    } on PlatformException catch (e, st) {
      if (kDebugMode) debugPrint('canCheckBiometrics failed: $e\n$st');
      return false;
    }
  }

  /// Whether the user has chosen to gate the app with biometrics. This is
  /// our app's preference — distinct from the OS-level enrollment.
  bool get isEnabled => _prefs.getBool(_kBiometricEnabledKey) ?? false;

  Future<void> setEnabled(bool value) async {
    await _prefs.setBool(_kBiometricEnabledKey, value);
  }

  /// Show the system biometric prompt. Returns true if the user authenticated.
  Future<bool> authenticate({String reason = 'Unlock Worship Hub'}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        authMessages: const [
          AndroidAuthMessages(
            signInTitle: 'Unlock Worship Hub',
            biometricHint: 'Verify it\'s you',
            cancelButton: 'Use password',
          ),
        ],
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // allow device PIN as fallback
        ),
      );
    } on PlatformException catch (e, st) {
      if (kDebugMode) debugPrint('authenticate failed: $e\n$st');
      return false;
    }
  }

  Future<void> signOutAndDisable() async {
    await setEnabled(false);
    await supabase.auth.signOut();
  }
}

/// In-memory flag: true while the current launch has already passed the
/// biometric gate. Reset on app restart so the user has to unlock again.
class UnlockSession extends StateNotifier<bool> {
  UnlockSession() : super(false);
  void unlock() => state = true;
  void relock() => state = false;
}

final unlockSessionProvider =
    StateNotifierProvider<UnlockSession, bool>((ref) => UnlockSession());

final sharedPrefsProvider = FutureProvider<SharedPreferences>(
  (ref) => SharedPreferences.getInstance(),
);

final biometricServiceProvider = Provider<BiometricService?>((ref) {
  final prefsAsync = ref.watch(sharedPrefsProvider);
  return prefsAsync.maybeWhen(
    data: (prefs) => BiometricService(prefs),
    orElse: () => null,
  );
});
