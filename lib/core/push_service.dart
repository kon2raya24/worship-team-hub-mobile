import 'package:firebase_messaging/firebase_messaging.dart';

import 'supabase_client.dart';

/// Registers this device's FCM token against the signed-in user so the
/// `send-push` Edge Function can reach them. Idempotent — safe to call on
/// every app launch; the device_tokens row is upserted by token.
class PushService {
  static bool _refreshWired = false;

  static Future<void> registerForUser(String userId) async {
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      final token = await messaging.getToken();
      if (token != null) await _store(userId, token);

      // Tokens rotate; keep the row current.
      if (!_refreshWired) {
        _refreshWired = true;
        messaging.onTokenRefresh.listen((t) => _store(userId, t));
      }
    } catch (_) {
      // Firebase/messaging unavailable (e.g. no Google Play services) — skip.
    }
  }

  static Future<void> _store(String userId, String token) async {
    try {
      await supabase.from('device_tokens').upsert(
        {
          'user_id': userId,
          'token': token,
          'platform': 'android',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'token',
      );
    } catch (_) {
      // Offline or transient — it'll re-register on the next launch.
    }
  }
}
