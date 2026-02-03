import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:follow/core/theme/app_theme.dart';
import 'package:follow/data/models/track.dart';
import 'package:follow/data/providers/audio_provider.dart';
import 'package:follow/data/providers/track_provider.dart';
import 'package:follow/data/services/api/api_service.dart';
import 'package:follow/shared/widgets/track_tile.dart';
import 'package:follow/shared/widgets/track_options_sheet.dart';

class SmartTrackTile extends ConsumerWidget {
  final Track track;
  final List<Track> playlist;
  final VoidCallback? onRemoveFromList;

  const SmartTrackTile({
    super.key,
    required this.track,
    required this.playlist,
    this.onRemoveFromList,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTrack = ref.watch(currentTrackProvider);
    final favoritesAsync = ref.watch(favoritesProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isFavorite = favoritesAsync.value?.any((t) => t.id == track.id) ?? false;
    final isPlaying = currentTrack?.id == track.id;

    return TrackTile(
      track: track,
      isPlaying: isPlaying,
      isFavorite: isFavorite,
      onTap: () {
        ref.read(currentTrackProvider.notifier).setTrack(track);
        ref.read(playQueueProvider.notifier).setQueue(playlist);
        final index = playlist.indexOf(track);
        if (index != -1) {
          ref.read(currentIndexProvider.notifier).setIndex(index);
        }
        ref.read(audioPlayerServiceProvider).playTrack(track);
      },
      onFavoriteToggle: (val) async {
        try {
          final apiService = ApiService();
          if (val) {
            await apiService.addToFavorites(track.id);
          } else {
            await apiService.removeFromFavorites(track.id);
          }
          ref.invalidate(favoritesProvider);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(val ? '已添加到收藏' : '已取消收藏'),
                backgroundColor: val ? Colors.green : Colors.grey,
                duration: const Duration(seconds: 1),
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
      onMorePressed: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: isDark ? LoginColors.gradientMid1 : null,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (context) => TrackOptionsSheet(
            track: track,
            onRemove: onRemoveFromList,
          ),
        );
      },
    );
  }
}
