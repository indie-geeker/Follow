import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:follow/data/providers/audio_provider.dart';
import 'package:follow/data/providers/history_provider.dart';
import 'package:follow/data/providers/api_provider.dart';
import 'package:follow/shared/widgets/smart_track_tile.dart';
import 'package:follow/shared/widgets/play_all_tile.dart';
import 'package:follow/core/utils/snackbar_helper.dart';
import 'package:follow/shared/widgets/loading/app_content_skeleton.dart';
import 'package:follow/shared/widgets/states/app_state_kind.dart';
import 'package:follow/shared/widgets/states/app_state_view.dart';

class RecentlyPlayedView extends ConsumerWidget {
  const RecentlyPlayedView({super.key, required this.onBrowseLibrary});

  final VoidCallback onBrowseLibrary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(historyProvider);
    return historyAsync.when(
      data: (tracks) {
        if (tracks.isEmpty) {
          return AppStateView(
            kind: AppStateKind.nothingPlaying,
            title: '暂无播放记录',
            description: '从音乐库挑一首喜欢的歌开始播放',
            actionLabel: '进入音乐库',
            onAction: onBrowseLibrary,
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
                  if (!context.mounted) return;
                  SnackBarHelper.showSuccess(context, '已移出最近播放');
                } catch (e) {
                  if (!context.mounted) return;
                  SnackBarHelper.showError(context, '操作失败: $e');
                }
              },
            );
          },
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: AppContentSkeleton(),
      ),
      error: (e, _) => AppStateView(
        kind: AppStateKind.failure,
        title: '播放记录加载失败',
        description: '暂时无法读取最近播放记录，请稍后重试。',
        actionLabel: '重试',
        onAction: () => ref.invalidate(historyProvider),
      ),
    );
  }
}
