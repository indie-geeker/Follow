import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:follow/data/providers/audio_provider.dart';
import 'package:follow/data/providers/track_provider.dart';
import 'package:follow/data/providers/api_provider.dart';
import 'package:follow/shared/widgets/smart_track_tile.dart';
import 'package:follow/shared/widgets/play_all_tile.dart';
import 'package:follow/core/utils/snackbar_helper.dart';
import 'package:follow/shared/widgets/loading/app_content_skeleton.dart';
import 'package:follow/shared/widgets/states/app_state_kind.dart';
import 'package:follow/shared/widgets/states/app_state_view.dart';

class FavoritesView extends ConsumerWidget {
  const FavoritesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesAsync = ref.watch(favoritesProvider);
    return favoritesAsync.when(
      data: (tracks) {
        if (tracks.isEmpty) {
          return const AppStateView(
            kind: AppStateKind.emptyLibrary,
            title: '暂无收藏',
            description: '浏览音乐库并添加喜欢的歌曲',
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
                  await apiService.removeFromFavorites(track.id);
                  ref.invalidate(favoritesProvider);
                  if (!context.mounted) return;
                  SnackBarHelper.showSuccess(context, '已移出收藏');
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
        title: '收藏加载失败',
        description: '暂时无法读取收藏内容，请稍后重试。',
        actionLabel: '重试',
        onAction: () => ref.invalidate(favoritesProvider),
      ),
    );
  }
}
