import 'package:flutter/material.dart';

import '../../../core/theme/follow_theme_tokens.dart';

class AuroraBackground extends StatelessWidget {
  const AuroraBackground({
    super.key,
    required this.child,
    this.primaryAccent,
    this.secondaryAccent,
    this.reduceMotion = false,
  });

  final Widget child;
  final Color? primaryAccent;
  final Color? secondaryAccent;

  /// Reserved for future transition effects. The current foundation is static
  /// in both modes so reduced motion never loses content or controls.
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final tokens = context.followTokens;
    final primary = primaryAccent ?? tokens.brandPrimary;
    final secondary = secondaryAccent ?? tokens.auroraCyan;

    return ColoredBox(
      color: tokens.background,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Align(
            alignment: const Alignment(-1.15, -1.05),
            child: Opacity(
              opacity: 0.28,
              child: _AuroraGlow(color: primary, sizeFactor: 1.2),
            ),
          ),
          Align(
            alignment: const Alignment(1.1, 0.9),
            child: Opacity(
              opacity: 0.22,
              child: _AuroraGlow(color: secondary, sizeFactor: 1.0),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _AuroraGlow extends StatelessWidget {
  const _AuroraGlow({required this.color, required this.sizeFactor});

  final Color color;
  final double sizeFactor;

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    widthFactor: sizeFactor,
    heightFactor: sizeFactor,
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
          stops: const [0, 1],
        ),
      ),
    ),
  );
}
