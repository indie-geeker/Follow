import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:follow/core/theme/app_theme.dart';
import 'package:follow/data/models/track.dart';
import 'package:follow/data/providers/audio_provider.dart';
import 'package:follow/shared/widgets/smart_track_tile.dart';

import '../../../data/providers/playlist_provider.dart';
import '../../../data/services/api/api_service.dart';

class PlaylistView extends ConsumerWidget {
  final String playlistId;

  const PlaylistView({super.key, required this.playlistId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistAsync = ref.watch(playlistDetailProvider(playlistId));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return playlistAsync.when(
      data: (playlist) {
        final tracks = playlist.tracks;
        if (tracks.isEmpty) {
          return _buildEmptyState(theme, isDark);
        }
        return ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: tracks.length,
          itemBuilder: (context, index) {
            final track = tracks[index];
            return SmartTrackTile(
              track: track,
              playlist: tracks,
              onRemoveFromList: () async {
                try {
                  final apiService = ApiService();
                  await apiService.removeTrackFromPlaylist(playlistId, track.id);
                  ref.invalidate(playlistDetailProvider(playlistId));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('已移出歌单'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('操作失败: $e'),
                        backgroundColor: theme.colorScheme.error,
                      ),
                    );
                  }
                }
              },
            );
          },
        );
      },
      loading: () =>
      const Center(
        child: CircularProgressIndicator(),
      ),
      error: (e, _) =>
          Center(
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
          color: isDark ? LoginColors.cardBackground : theme.colorScheme
              .surfaceContainerHighest,
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
                Icons.music_note_rounded,
                size: 32,
                color: isDark ? LoginColors.accentPurple : theme.colorScheme
                    .primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '空歌单',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '添加一些歌曲吧',
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
}
