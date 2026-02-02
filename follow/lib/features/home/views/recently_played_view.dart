import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:follow/core/theme/app_theme.dart';
import 'package:follow/data/models/track.dart';
import 'package:follow/data/providers/audio_provider.dart';
import 'package:follow/data/providers/history_provider.dart';
import 'package:follow/data/providers/track_provider.dart';
import 'package:follow/shared/widgets/track_tile.dart';

class RecentlyPlayedView extends ConsumerWidget {
  const RecentlyPlayedView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(historyProvider);
    final currentTrack = ref.watch(currentTrackProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return historyAsync.when(
      data: (tracks) {
        if (tracks.isEmpty) {
          return _buildEmptyState(theme, isDark);
        }
        return ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: tracks.length,
          itemBuilder: (context, index) {
            final track = tracks[index];
            return TrackTile(
              track: track,
              isPlaying: currentTrack?.id == track.id,
              onTap: () => _playTrack(ref, track, tracks),
            );
          },
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              '加载失败',
              style: TextStyle(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, bool isDark) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: isDark ? LoginColors.cardBackground : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? LoginColors.cardBorder : Colors.transparent,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    LoginColors.accentPurple.withValues(alpha: 0.2),
                    LoginColors.accentPink.withValues(alpha: 0.2),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.history_rounded,
                size: 32,
                color: isDark ? LoginColors.accentPurple : theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '暂无播放记录',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '快去听听歌吧',
              style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? LoginColors.textSecondary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _playTrack(WidgetRef ref, Track track, List<Track> tracks) {
    ref.read(currentTrackProvider.notifier).setTrack(track);
    ref.read(playQueueProvider.notifier).setQueue(List.from(tracks));
    ref.read(audioPlayerServiceProvider).playTrack(track);
  }
}
