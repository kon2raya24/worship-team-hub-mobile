# Worship Team Hub — Mobile (Flutter)

Native Android companion to the web app at `worship-team-hub.vercel.app`. Same Supabase backend, offline-first.

## Status

Phase 1 scaffold:
- Sanctuary OS theme port (colors, fonts, aurora background, glass cards)
- Supabase auth (email/password)
- Auth-gated router (go_router + Riverpod)
- Songs list + setlists list (network reads, offline cache wiring next)
- Placeholder song detail (raw ChordPro shown; custom parser + transposer + viewer is the next module)

What's NOT here yet:
- Drift schema + sync service (offline-first cache)
- ChordPro parser / transposer / formatter
- Leader write flows
- Push notifications (deferred to Phase 2)

## Setup

1. Install Flutter (3.35+) — https://docs.flutter.dev/get-started/install
2. `flutter doctor` — fix any Android toolchain issues
3. Clone this repo into your workspace
4. `flutter pub get`

## Running

This app reads its Supabase config from `--dart-define` flags at build time. Never commit real keys.

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbG...
```

Tip: put those into a launch config (VS Code) or a shell alias so you don't retype them.

### VS Code (.vscode/launch.json)

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "worship-team-hub (dev)",
      "type": "dart",
      "request": "launch",
      "program": "lib/main.dart",
      "args": [
        "--dart-define=SUPABASE_URL=https://YOUR.supabase.co",
        "--dart-define=SUPABASE_ANON_KEY=eyJhbG..."
      ]
    }
  ]
}
```

## Building a release APK

```bash
flutter build apk --release \
  --dart-define=SUPABASE_URL=https://YOUR.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbG...
```

Output lands at `build/app/outputs/flutter-apk/app-release.apk`.

Sideload to a phone with ADB:
```bash
adb install build/app/outputs/flutter-apk/app-release.apk
```

For Play Store distribution, follow https://docs.flutter.dev/deployment/android to set up signing.

## Project layout

```
lib/
├── main.dart              # Entry: Supabase.initialize + ProviderScope
├── app.dart               # MaterialApp.router with theme + AuroraBackground
├── core/
│   ├── env.dart           # Reads SUPABASE_URL / SUPABASE_ANON_KEY from --dart-define
│   ├── theme.dart         # Sanctuary OS palette + ThemeData + GlassCard + AuroraBackground
│   ├── supabase_client.dart
│   └── router.dart        # go_router with auth gate
└── features/
    ├── auth/
    │   ├── auth_provider.dart   # Riverpod auth state stream
    │   └── ui/login_screen.dart
    ├── home/ui/home_screen.dart
    ├── songs/ui/songs_list_screen.dart, song_detail_screen.dart
    └── setlists/ui/setlists_list_screen.dart
```

Next sprint adds `data/db/` (Drift) and `features/songs/chordpro/` (parser, transposer, formatter).

## Backend contract

This app talks to the same Supabase project as the web app — see the web repo for the schema (`supabase/migrations/0001_init.sql`) and RLS policies. Don't run migrations from this app; that's the web repo's responsibility.

## Conventions

- Riverpod for state. Avoid `setState` except for ephemeral form state.
- `go_router` for nav. Use `context.go('/path')` not `Navigator.push`.
- All reads will go through Drift (local DB) once that lands; remote becomes a sync source, not a UI dependency.
- Colors + typography come from `core/theme.dart` only — no inline hex codes elsewhere.
