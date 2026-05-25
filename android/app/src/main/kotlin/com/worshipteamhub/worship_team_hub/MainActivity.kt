package com.worshipteamhub.worship_team_hub

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity (instead of FlutterActivity) is required by local_auth
// so the biometric BiometricPrompt can attach as a DialogFragment.
class MainActivity : FlutterFragmentActivity()
