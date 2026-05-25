import 'package:flutter/material.dart';

import '../../../core/theme.dart';

/// The Sanctuary OS brand-mark — conic ring + inner gradient square.
/// Used on auth screens. Same composition as the launcher icon.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.18),
        gradient: const SweepGradient(
          startAngle: 2.4,
          colors: [
            Sanctuary.auroraCyan,
            Sanctuary.auroraViolet,
            Sanctuary.auroraMagenta,
            Sanctuary.auroraCyan,
          ],
        ),
      ),
      child: Center(
        child: Container(
          width: size * 0.65,
          height: size * 0.65,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.12),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Sanctuary.auroraCyan, Sanctuary.auroraViolet],
            ),
          ),
        ),
      ),
    );
  }
}
