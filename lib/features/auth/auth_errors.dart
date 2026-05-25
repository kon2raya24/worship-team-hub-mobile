import 'package:supabase_flutter/supabase_flutter.dart';

/// Translate raw Supabase / network errors into messages a non-engineer
/// can actually act on. Falls back to the raw message only when we don't
/// have a known case.
String friendlyAuthError(Object error) {
  if (error is AuthException) {
    final msg = error.message.toLowerCase();
    if (msg.contains('invalid login credentials') ||
        msg.contains('invalid email or password')) {
      return 'Wrong email or password.';
    }
    if (msg.contains('email not confirmed')) {
      return 'Confirm your email — we sent you a link.';
    }
    if (msg.contains('user already registered') ||
        msg.contains('already registered')) {
      return 'That email is already in use. Sign in instead.';
    }
    if (msg.contains('password should be at least') ||
        msg.contains('password should be at least 6 characters') ||
        msg.contains('weak password')) {
      return 'Pick a stronger password (8+ characters).';
    }
    if (msg.contains('unable to validate email') ||
        msg.contains('invalid email')) {
      return 'That doesn\'t look like a valid email address.';
    }
    if (msg.contains('rate limit') || msg.contains('over_email_send')) {
      return 'Too many attempts. Wait a minute and try again.';
    }
    if (msg.contains('email rate limit')) {
      return 'We\'ve sent too many emails to this address recently. Try again later.';
    }
    if (msg.contains('user not found')) {
      return 'No account with that email.';
    }
    if (msg.contains('signup is disabled') ||
        msg.contains('signups not allowed')) {
      return 'New sign-ups are currently closed. Ask your worship leader.';
    }
    // Network-ish failures wrapped in AuthException
    if (msg.contains('failed host lookup') ||
        msg.contains('network is unreachable') ||
        msg.contains('socketexception')) {
      return 'Can\'t reach the server. Check your connection.';
    }
    // Generic fall-through — show the original (already user-readable).
    return _toSentence(error.message);
  }
  final s = error.toString().toLowerCase();
  if (s.contains('socketexception') ||
      s.contains('failed host lookup') ||
      s.contains('network is unreachable')) {
    return 'Can\'t reach the server. Check your connection.';
  }
  if (s.contains('timeoutexception')) {
    return 'Server took too long to respond. Try again.';
  }
  return 'Something went wrong. Try again.';
}

String _toSentence(String s) {
  if (s.isEmpty) return s;
  final trimmed = s.trim();
  final firstUpper = trimmed[0].toUpperCase() + trimmed.substring(1);
  return firstUpper.endsWith('.') ? firstUpper : '$firstUpper.';
}
