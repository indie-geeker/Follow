import 'package:flutter/material.dart';
import 'package:follow/core/theme/app_theme.dart';

/// App logo widget with gradient icon and title text.
class AppLogo extends StatelessWidget {
  final double size;

  const AppLogo({super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Row(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                LoginColors.accentPurple,
                LoginColors.accentPink,
              ],
            ),
            borderRadius: BorderRadius.circular(size * 0.3),
            boxShadow: [
              BoxShadow(
                color: LoginColors.accentPurple.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            Icons.music_note_rounded,
            color: Colors.white,
            size: size * 0.55,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'Follow Music',
          style: TextStyle(
            fontSize: size * 0.5,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
