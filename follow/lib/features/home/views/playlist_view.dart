import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:follow/data/providers/audio_provider.dart';
import 'package:follow/data/providers/api_provider.dart';
import 'package:follow/shared/widgets/smart_track_tile.dart';
import 'package:follow/shared/widgets/play_all_tile.dart';
import 'package:follow/core/utils/snackbar_helper.dart';
import 'package:follow/shared/widgets/loading/app_content_skeleton.dart';
import 'package:follow/shared/widgets/states/app_state_kind.dart';
import 'package:follow/shared/widgets/states/app_state_view.dart';

import '../../../data/providers/playlist_provider.dart';

class PlaylistView extends ConsumerWidget {
  final String playlistId;

  const PlaylistView({super.key, required this.playlistId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistAsync = ref.watch(playlistDetailProvider(playlistId));
    return playlistAsync.when(
      data: (playlist) {
        final tracks = playlist.tracks;
        if (tracks.isEmpty) {
          return AppStateView(
            kind: AppStateKind.emptyPlaylist,
            title: '空歌单',
            description: playlist.canEdit
                ? '添加一些歌曲吧'
                : '该公开歌单由 ${playlist.ownerName ?? '其他家庭成员'} 管理',
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
                  ref
                      .read(audioPlayerServiceProvider)
                      .playPlaylist(playlistId, tracks);
                },
              );
            }
            final track = tracks[index - 1];
            return SmartTrackTile(
              track: track,
              playlist: tracks,
              sourcePlaylistId: playlistId,
              onRemoveFromList: playlist.canEdit
                  ? () async {
                      try {
                        final apiService = ref.read(apiServiceProvider);
                        await apiService.removeTrackFromPlaylist(
                          playlistId,
                          track.id,
                        );
                        ref.invalidate(playlistDetailProvider(playlistId));
                        if (!context.mounted) return;
                        SnackBarHelper.showSuccess(context, '已移出歌单');
                      } catch (e) {
                        if (!context.mounted) return;
                        SnackBarHelper.showError(context, '操作失败: $e');
                      }
                    }
                  : null,
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
        title: '歌单加载失败',
        description: '暂时无法读取歌单内容，请稍后重试。',
        actionLabel: '重试',
        onAction: () => ref.invalidate(playlistDetailProvider(playlistId)),
      ),
    );
  }
}
