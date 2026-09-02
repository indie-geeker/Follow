import 'package:flutter/material.dart';
import 'package:follow/core/theme/follow_theme_tokens.dart';

/// A small action button with icon for download actions.
class DownloadActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool isDestructive;

  const DownloadActionButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDestructive
              ? Colors.red.withValues(alpha: 0.15)
              : (isDark
                    ? context.followTokens.brandPrimary.withValues(alpha: 0.2)
                    : context.followTokens.brandPrimary.withValues(alpha: 0.1)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 20,
          color: isDestructive ? Colors.red : context.followTokens.brandPrimary,
        ),
      ),
    );
  }
}
