import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:follow/data/providers/audio_provider.dart';
import 'package:follow/data/providers/history_provider.dart';
import 'package:follow/data/providers/api_provider.dart';
import 'package:follow/shared/widgets/smart_track_tile.dart';
import 'package:follow/shared/widgets/play_all_tile.dart';
import 'package:follow/shared/widgets/empty_state_card.dart';
import 'package:follow/core/utils/snackbar_helper.dart';

class RecentlyPlayedView extends ConsumerWidget {
  const RecentlyPlayedView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(historyProvider);
    final theme = Theme.of(context);

    return historyAsync.when(
      data: (tracks) {
        if (tracks.isEmpty) {
          return const EmptyStateCard(
            icon: Icons.history_rounded,
            title: '暂无播放记录',
            subtitle: '快去听听歌吧',
          );
        }
        return ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: tracks.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return PlayAllTile(
                count: tracks.length,
                onTap: () {
                  ref.read(audioPlayerServiceProvider).playAll(tracks);
                },
              );
            }
            final track = tracks[index - 1];
            return SmartTrackTile(
              track: track,
              playlist: tracks,
              onRemoveFromList: () async {
                try {
                  final apiService = ref.read(apiServiceProvider);
                  await apiService.removeFromHistory(track.id);
                  ref.invalidate(historyProvider);
                  SnackBarHelper.showSuccess(context, '已移出最近播放');
                } catch (e) {
                  SnackBarHelper.showError(context, '操作失败: $e');
                }
              },
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
}
