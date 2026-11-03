import 'package:blocodenotasturmab/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Logotipo: a palavra "grafite" com um traço de marca-texto por baixo.
class GrafiteLogo extends StatelessWidget {
  const GrafiteLogo({super.key, this.size = 44});

  final double size;

  @override
  Widget build(BuildContext context) {
    final ink = Theme.of(context).colorScheme.onSurface;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: -size * 0.08,
          right: -size * 0.12,
          bottom: size * 0.12,
          height: size * 0.42,
          child: Transform.rotate(
            angle: -0.02,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: GrafiteColors.highlighter.withValues(
                  alpha: dark ? 0.35 : 0.85,
                ),
                borderRadius: BorderRadius.circular(size * 0.08),
              ),
            ),
          ),
        ),
        Text(
          'grafite',
          style: GoogleFonts.fraunces(
            fontSize: size,
            fontWeight: FontWeight.w700,
            fontStyle: FontStyle.italic,
            letterSpacing: -size * 0.02,
            color: ink,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}
