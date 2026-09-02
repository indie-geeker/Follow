import 'package:flutter/material.dart';
import 'package:follow/core/theme/follow_theme_tokens.dart';
import 'package:follow/data/models/user.dart';

/// User avatar with gradient border and initial letter.
class UserAvatar extends StatelessWidget {
  final User user;
  final double radius;

  const UserAvatar({super.key, required this.user, this.radius = 18});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: context.followTokens.brandPrimary.withValues(alpha: 0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: context.followTokens.brandPrimary.withValues(alpha: 0.2),
            blurRadius: 8,
          ),
        ],
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: isDark
            ? context.followTokens.surface
            : theme.colorScheme.primaryContainer,
        child: Text(
          user.username[0].toUpperCase(),
          style: TextStyle(
            color: isDark ? Colors.white : theme.colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
            fontSize: radius * 0.78,
          ),
        ),
      ),
    );
  }
}
