import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kBiometricEnabledKey = 'biometric_enabled';
const _kEmailKey = 'biometric_email';
const _kPasswordKey = 'biometric_password';
const _kUserIdKey = 'biometric_user_id';

const _secureOpts = AndroidOptions(encryptedSharedPreferences: true);

/// Wraps local_auth + secure-storage-backed credentials so the login screen
/// can offer "Sign in with fingerprint" on subsequent launches.
class BiometricService {
  BiometricService(this._prefs);

  final SharedPreferences _prefs;
  final LocalAuthentication _auth = LocalAuthentication();
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: _secureOpts,
  );

  /// Hardware + OS support check (doesn't require the user to have enrolled
  /// a fingerprint).
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

  /// True once the user has enrolled biometric sign-in for this app +
  /// credentials are stored.
  bool get isEnabled => _prefs.getBool(_kBiometricEnabledKey) ?? false;

  /// Whether credentials are actually present in secure storage. Used to
  /// detect a stale [isEnabled] flag left over from an older app version
  /// (or after the user uninstalled and reinstalled — secure storage
  /// gets wiped, but shared_preferences may survive on some launchers).
  Future<bool> hasStoredCredentials() async {
    final email = await _storage.read(key: _kEmailKey, aOptions: _secureOpts);
    final password = await _storage.read(
      key: _kPasswordKey,
      aOptions: _secureOpts,
    );
    return email != null && password != null;
  }

  /// Show the system biometric prompt.
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
          biometricOnly: false,
        ),
      );
    } on PlatformException catch (e, st) {
      if (kDebugMode) debugPrint('authenticate failed: $e\n$st');
      return false;
    }
  }

  /// Persist credentials behind secure storage + mark biometric enabled.
  /// Call this after a successful password sign-in if the user opted in.
  Future<void> enrollWithCredentials({
    required String email,
    required String password,
    String? userId,
  }) async {
    await rememberCredentials(
      email: email,
      password: password,
      userId: userId,
    );
    await _prefs.setBool(_kBiometricEnabledKey, true);
  }

  /// Store credentials in secure storage without enabling biometric. Used by
  /// the "Remember me" path so the same account can sign in offline by typing
  /// the password — even on devices without (or that haven't opted in to)
  /// biometric.
  ///
  /// [userId] is the Supabase auth.users id; storing it lets the home screen
  /// look up the user's profile (display name, role) from the local Drift
  /// cache when we're offline and `supabase.auth.currentUser` is null.
  Future<void> rememberCredentials({
    required String email,
    required String password,
    String? userId,
  }) async {
    await _storage.write(key: _kEmailKey, value: email, aOptions: _secureOpts);
    await _storage.write(
      key: _kPasswordKey,
      value: password,
      aOptions: _secureOpts,
    );
    if (userId != null) {
      await _storage.write(
        key: _kUserIdKey,
        value: userId,
        aOptions: _secureOpts,
      );
    }
  }

  /// Read the user id stashed alongside the credentials, if any.
  Future<String?> readUserId() =>
      _storage.read(key: _kUserIdKey, aOptions: _secureOpts);

  /// Compare typed credentials against the last successfully signed-in pair.
  /// Used as the offline-password fallback when the network is unreachable.
  Future<bool> verifyStoredCredentials({
    required String email,
    required String password,
  }) async {
    final stored = await readCredentials();
    if (stored == null) return false;
    return stored.email == email && stored.password == password;
  }

  /// Read stored credentials (call after a successful biometric prompt).
  /// Returns null if anything is missing.
  Future<({String email, String password})?> readCredentials() async {
    final email = await _storage.read(key: _kEmailKey, aOptions: _secureOpts);
    final password = await _storage.read(
      key: _kPasswordKey,
      aOptions: _secureOpts,
    );
    if (email == null || password == null) return null;
    return (email: email, password: password);
  }

  /// Disable biometric sign-in and forget the stored credentials.
  Future<void> disable() async {
    await _storage.delete(key: _kEmailKey, aOptions: _secureOpts);
    await _storage.delete(key: _kPasswordKey, aOptions: _secureOpts);
    await _storage.delete(key: _kUserIdKey, aOptions: _secureOpts);
    await _prefs.setBool(_kBiometricEnabledKey, false);
  }
}

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
