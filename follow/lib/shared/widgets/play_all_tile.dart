import 'package:flutter/material.dart';
import 'package:follow/core/theme/follow_theme_tokens.dart';

class PlayAllTile extends StatelessWidget {
  final VoidCallback onTap;
  final int count;
  final bool isSliver;

  const PlayAllTile({
    super.key,
    required this.onTap,
    required this.count,
    this.isSliver = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final content = InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: context.followTokens.brandPrimary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: context.followTokens.brandPrimary.withValues(
                      alpha: 0.3,
                    ),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '播放全部',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  '$count 首歌曲',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? context.followTokens.textSecondary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (isSliver) {
      return SliverToBoxAdapter(child: content);
    }
    return content;
  }
}
