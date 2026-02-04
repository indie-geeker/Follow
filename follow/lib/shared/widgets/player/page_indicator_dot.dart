import 'package:flutter/material.dart';

/// A simple dot indicator for page view navigation.
class PageIndicatorDot extends StatelessWidget {
  final bool isActive;
  final double size;

  const PageIndicatorDot({
    super.key,
    required this.isActive,
    this.size = 8,
  });

  Color _foregroundColor(BuildContext context, {double alpha = 1.0}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.white : Colors.black87;
    return alpha < 1.0 ? baseColor.withValues(alpha: alpha) : baseColor;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive
            ? _foregroundColor(context)
            : _foregroundColor(context, alpha: 0.3),
      ),
    );
  }
}
