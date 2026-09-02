import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:follow/core/theme/follow_theme_tokens.dart';
import 'package:follow/data/models/track.dart';
import 'package:follow/data/providers/download_provider.dart';
import 'package:follow/shared/widgets/add_to_playlist_dialog.dart';

class TrackOptionsSheet extends ConsumerWidget {
  final Track track;
  final VoidCallback? onRemove;

  const TrackOptionsSheet({super.key, required this.track, this.onRemove});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: isDark
                    ? context.followTokens.textSecondary
                    : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            _OptionItem(
              icon: Icons.playlist_add_rounded,
              title: '加入歌单',
              onTap: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (context) => AddToPlaylistDialog(track: track),
                );
              },
            ),
            if (onRemove != null)
              _OptionItem(
                icon: Icons.playlist_remove_rounded,
                title: '移出歌单',
                onTap: () {
                  Navigator.pop(context);
                  onRemove!();
                },
              ),
            _OptionItem(
              icon: Icons.download_outlined,
              title: '下载',
              onTap: () {
                Navigator.pop(context);
                ref.read(downloadManagerProvider.notifier).downloadTrack(track);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('已添加到下载队列'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _OptionItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark
              ? context.followTokens.brandPrimary.withValues(alpha: 0.2)
              : theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: isDark
              ? context.followTokens.brandPrimary
              : theme.colorScheme.primary,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDark ? Colors.white : theme.colorScheme.onSurface,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }
}
