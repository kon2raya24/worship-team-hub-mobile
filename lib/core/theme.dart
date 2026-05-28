import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Sanctuary OS — dark glass + aurora gradients, ported from the web app
/// (app/globals.css). Single source of truth for colors, radii, fonts.
class Sanctuary {
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

  // Radii (matches --radius: 0.5rem)
  static const radiusSm = 6.0;
  static const radiusMd = 8.0;
  static const radiusLg = 10.0;

  static ThemeData buildTheme() {
    final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
    final textTheme = GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: foreground,
      displayColor: foreground,
    );

    return base.copyWith(
      scaffoldBackgroundColor: ink0,
      canvasColor: ink0,
      colorScheme: const ColorScheme.dark(
        surface: ink0,
        primary: auroraViolet,
        onPrimary: Colors.white,
        secondary: auroraCyan,
        onSecondary: ink0,
        error: destructive,
        onSurface: foreground,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: ink1.withValues(alpha: 0.75),
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: foreground,
        titleTextStyle: GoogleFonts.spaceGrotesk(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.02 * 16,
          color: foreground,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: auroraViolet,
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
          foregroundColor: foreground,
          side: const BorderSide(color: hairline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: glass1,
        hintStyle: const TextStyle(color: muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: auroraViolet.withValues(alpha: 0.55)),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
      cardTheme: CardThemeData(
        color: glass1,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: const BorderSide(color: hairline),
        ),
      ),
    );
  }

  /// Display font (Space Grotesk) — use for headings and the brand mark.
  static TextStyle display({
    double fontSize = 24,
    FontWeight fontWeight = FontWeight.w600,
    Color color = foreground,
  }) =>
      GoogleFonts.spaceGrotesk(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: -0.02 * fontSize,
      );

  /// Mono font (JetBrains Mono) — use for eyebrows, chord chips, code.
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

/// Aurora gradient background painted under the whole app.
class AuroraBackground extends StatelessWidget {
  const AuroraBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF060916), Color(0xFF04060E), Color(0xFF03050C)],
          stops: [0, 0.6, 1],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: -120,
            top: -160,
            child: _AuroraBlob(
              color: Sanctuary.auroraViolet.withValues(alpha: 0.30),
              size: 460,
            ),
          ),
          Positioned(
            right: -120,
            top: 220,
            child: _AuroraBlob(
              color: Sanctuary.auroraCyan.withValues(alpha: 0.22),
              size: 400,
            ),
          ),
          Positioned(
            left: 60,
            bottom: -120,
            child: _AuroraBlob(
              color: Sanctuary.auroraMagenta.withValues(alpha: 0.18),
              size: 360,
            ),
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

/// Glass panel — frosted, hairline-bordered card. Use sparingly.
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
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Sanctuary.glass1,
        border: Border.all(color: Sanctuary.hairline),
        borderRadius: BorderRadius.circular(Sanctuary.radiusLg),
      ),
      child: child,
    );
  }
}
