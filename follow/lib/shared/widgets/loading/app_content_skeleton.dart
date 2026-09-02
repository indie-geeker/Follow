import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/theme/follow_theme_tokens.dart';

class AppContentSkeleton extends StatelessWidget {
  const AppContentSkeleton({
    super.key,
    this.itemCount = 4,
    this.itemHeight = 72,
    this.spacing = 12,
    this.reduceMotion = false,
  }) : assert(itemCount > 0),
       assert(itemHeight > 0),
       assert(spacing >= 0);

  final int itemCount;
  final double itemHeight;
  final double spacing;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final tokens = context.followTokens;
    final content = SizedBox(
      key: const Key('skeleton-content'),
      height: itemCount * itemHeight + (itemCount - 1) * spacing,
      child: Column(
        children: List.generate(itemCount, (index) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: index == itemCount - 1 ? 0 : spacing,
            ),
            child: SizedBox(
              height: itemHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: tokens.surfaceElevated,
                  borderRadius: BorderRadius.circular(tokens.radiusCard),
                ),
              ),
            ),
          );
        }),
      ),
    );
    final motionDisabled =
        reduceMotion || MediaQuery.maybeOf(context)?.disableAnimations == true;

    if (motionDisabled) return content;
    return Shimmer.fromColors(
      baseColor: tokens.surfaceElevated,
      highlightColor: tokens.surface,
      period: tokens.motionPalette * 4,
      child: content,
    );
  }
}
