import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Sanctuary OS — aurora gradients + glass panels, ported from the web app
/// (app/globals.css). Single source of truth for colors, radii, fonts.
///
/// Two palettes: the dark ("night") consts below mirror `.dark` in globals.css,
/// and the `light*` consts mirror `:root`. [buildTheme] takes a [Brightness] so
/// the app can offer Light / Dark / System. Screens should prefer
/// `Theme.of(context).colorScheme` over the raw consts so they follow the theme.
class Sanctuary {
  // ── Dark ("night") palette ────────────────────────────────────────────
  // Ink / surface
  static const ink0 = Color(0xFF04060E);
  static const ink1 = Color(0xFF070A17);
  static const ink2 = Color(0xFF0B1024);
  static const ink3 = Color(0xFF121838);

  // Glass overlays
  static const glass1 = Color(0x0DFFFFFF); // rgba(255,255,255,0.05)
  static const glass2 = Color(0x14FFFFFF); // rgba(255,255,255,0.08)
  static const hairline = Color(0x14FFFFFF);
  static const hairlineStrong = Color(0x29FFFFFF);

  // Aurora accent palette
  static const auroraCyan = Color(0xFF00E8FF);
  static const auroraViolet = Color(0xFF8B5CF6);
  static const auroraMagenta = Color(0xFFFF3AA3);
  static const auroraAmber = Color(0xFFFFB547);

  // Typography
  static const foreground = Color(0xFFF5F7FF);
  static const muted = Color(0xFF8A92B4);

  // Status
  static const success = Color(0xFF8EFF6A);
  static const destructive = Color(0xFFFF5566);

  // ── Light ("day") palette — mirrors :root in app/globals.css ──────────
  static const lightInk0 = Color(0xFFF6F7FB); // scaffold background
  static const lightInk1 = Color(0xFFFFFFFF); // raised surfaces / app bar
  static const lightInk2 = Color(0xFFEEF0F7);
  static const lightForeground = Color(0xFF0B1024);
  static const lightMuted = Color(0xFF5A6178);
  static const lightGlass1 = Color(0x0A111838); // rgba(17,24,56,0.04)
  static const lightHairline = Color(0x1A111838); // rgba(17,24,56,0.10)
  static const lightHairlineStrong = Color(0x2E111838); // ~rgba(17,24,56,0.18)
  static const lightViolet = Color(0xFF7C3AED);
  static const lightCyan = Color(0xFF0E9BB8);
  static const lightMagenta = Color(0xFFD81B75);
  static const lightSuccess = Color(0xFF16A34A);
  static const lightDestructive = Color(0xFFE11D48);

  // Radii (matches --radius: 0.5rem)
  static const radiusSm = 6.0;
  static const radiusMd = 8.0;
  static const radiusLg = 10.0;

  static ThemeData buildTheme([Brightness brightness = Brightness.dark]) {
    final isDark = brightness == Brightness.dark;
    final base = ThemeData(brightness: brightness, useMaterial3: true);

    final fg = isDark ? foreground : lightForeground;
    final mutedColor = isDark ? muted : lightMuted;
    final surface = isDark ? ink0 : lightInk0;
    final glassFill = isDark ? glass1 : lightGlass1;
    final line = isDark ? hairline : lightHairline;
    final lineStrong = isDark ? hairlineStrong : lightHairlineStrong;
    final primary = isDark ? auroraViolet : lightViolet;
    final secondary = isDark ? auroraCyan : lightCyan;
    final errorColor = isDark ? destructive : lightDestructive;

    final textTheme = GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: fg,
      displayColor: fg,
    );

    final colorScheme = base.colorScheme.copyWith(
      surface: surface,
      onSurface: fg,
      onSurfaceVariant: mutedColor,
      primary: primary,
      onPrimary: Colors.white,
      secondary: secondary,
      onSecondary: isDark ? ink0 : Colors.white,
      error: errorColor,
      onError: Colors.white,
      outline: lineStrong,
      outlineVariant: line,
    );

    return base.copyWith(
      scaffoldBackgroundColor: surface,
      canvasColor: surface,
      colorScheme: colorScheme,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: (isDark ? ink1 : lightInk1).withValues(alpha: 0.75),
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: fg,
        titleTextStyle: GoogleFonts.spaceGrotesk(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.02 * 16,
          color: fg,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: fg,
          side: BorderSide(color: line),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        // On light, a 4%-tint fill + 10% border made fields nearly invisible on
        // a white card — give light a clearer grey fill + stronger border.
        fillColor: isDark ? glassFill : const Color(0xFFF0F2F8),
        hintStyle: TextStyle(color: mutedColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: isDark ? line : lightHairlineStrong),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: isDark ? line : lightHairlineStrong),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: primary.withValues(alpha: 0.55)),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
      cardTheme: CardThemeData(
        color: glassFill,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: BorderSide(color: line),
        ),
      ),
      // Consistent, subtle page transition for pushed routes (detail/compose)
      // on both platforms. Tab switches use an IndexedStack, so they stay
      // instant — only pushed MaterialPages pick this up.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _SubtlePageTransitions(),
          TargetPlatform.iOS: _SubtlePageTransitions(),
        },
      ),
    );
  }

  /// Display font (Space Grotesk) — use for headings and the brand mark.
  /// Leave [color] null to inherit the theme's foreground (so headings follow
  /// light/dark automatically); pass a color only to override.
  static TextStyle display({
    double fontSize = 24,
    FontWeight fontWeight = FontWeight.w600,
    Color? color,
  }) =>
      GoogleFonts.spaceGrotesk(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: -0.02 * fontSize,
      );

  /// Mono font (JetBrains Mono) — use for eyebrows, chord chips, code.
  /// Defaults to the dark muted tone; pass `color: cs.onSurfaceVariant` from a
  /// screen so the label stays readable in light mode too.
  static TextStyle mono({
    double fontSize = 10,
    FontWeight fontWeight = FontWeight.w500,
    Color color = muted,
    double letterSpacing = 1.6,
  }) =>
      GoogleFonts.jetBrainsMono(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
      );
}

/// Aurora gradient background painted under the whole app. Follows the active
/// brightness so light mode gets a soft, near-white wash instead of deep space.
class AuroraBackground extends StatelessWidget {
  const AuroraBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradientColors = isDark
        ? const [Color(0xFF060916), Color(0xFF04060E), Color(0xFF03050C)]
        : const [Color(0xFFFBFBFF), Color(0xFFF4F6FC), Color(0xFFEEF1F9)];
    final violet = (isDark ? Sanctuary.auroraViolet : Sanctuary.lightViolet)
        .withValues(alpha: isDark ? 0.30 : 0.12);
    final cyan = (isDark ? Sanctuary.auroraCyan : Sanctuary.lightCyan)
        .withValues(alpha: isDark ? 0.22 : 0.10);
    final magenta = (isDark ? Sanctuary.auroraMagenta : Sanctuary.lightMagenta)
        .withValues(alpha: isDark ? 0.18 : 0.08);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: gradientColors,
          stops: const [0, 0.6, 1],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: -120,
            top: -160,
            child: _AuroraBlob(color: violet, size: 460),
          ),
          Positioned(
            right: -120,
            top: 220,
            child: _AuroraBlob(color: cyan, size: 400),
          ),
          Positioned(
            left: 60,
            bottom: -120,
            child: _AuroraBlob(color: magenta, size: 360),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class _AuroraBlob extends StatelessWidget {
  const _AuroraBlob({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}

/// Glass panel — frosted, hairline-bordered card. Use sparingly. Follows the
/// active brightness via the theme's colorScheme.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: isDark ? Sanctuary.glass1 : Sanctuary.lightGlass1,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(Sanctuary.radiusLg),
      ),
      child: child,
    );
  }
}

/// Compact, on-brand placeholder for "nothing here yet" lists — a tinted icon
/// chip over a title + optional hint. Centre it inside a scrollable so
/// pull-to-refresh still works.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.accent,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// Accent for the icon chip. Defaults to the theme's primary when null.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accentColor = accent ?? cs.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.10),
              border: Border.all(color: accentColor.withValues(alpha: 0.30)),
              borderRadius: BorderRadius.circular(Sanctuary.radiusLg),
            ),
            child: Icon(icon, size: 24, color: accentColor),
          ),
          const SizedBox(height: 14),
          Text(title,
              textAlign: TextAlign.center,
              style: Sanctuary.display(fontSize: 16, color: cs.onSurface)),
          if ((subtitle ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: cs.onSurfaceVariant, fontSize: 13, height: 1.4)),
          ],
        ],
      ),
    );
  }
}

/// A gentle fade + slight upward slide for pushed routes, so screen pushes
/// feel cohesive across Android and iOS rather than platform-default. Wired in
/// via [Sanctuary.buildTheme]'s `pageTransitionsTheme`.
class _SubtlePageTransitions extends PageTransitionsBuilder {
  const _SubtlePageTransitions();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.02),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}
