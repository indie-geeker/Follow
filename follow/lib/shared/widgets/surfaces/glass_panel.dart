import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/theme/follow_theme_tokens.dart';

enum GlassTier { light, standard, strong }

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.tier = GlassTier.standard,
    this.borderRadius,
    this.padding,
  });

  final Widget child;
  final GlassTier tier;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final tokens = context.followTokens;
    final spec = switch (tier) {
      GlassTier.light => tokens.glassLight,
      GlassTier.standard => tokens.glassStandard,
      GlassTier.strong => tokens.glassStrong,
    };
    final radius = borderRadius ?? BorderRadius.circular(tokens.radiusPanel);

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter.grouped(
        filter: ImageFilter.blur(
          sigmaX: spec.blurSigma,
          sigmaY: spec.blurSigma,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: spec.fill,
            border: Border.all(color: spec.border),
            borderRadius: radius,
          ),
          child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
        ),
      ),
    );
  }
}
