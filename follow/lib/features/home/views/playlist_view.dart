import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:follow/data/providers/audio_provider.dart';
import 'package:follow/data/providers/api_provider.dart';
import 'package:follow/shared/widgets/smart_track_tile.dart';
import 'package:follow/shared/widgets/play_all_tile.dart';
import 'package:follow/shared/widgets/empty_state_card.dart';
import 'package:follow/core/utils/snackbar_helper.dart';

import '../../../data/providers/playlist_provider.dart';

class PlaylistView extends ConsumerWidget {
  final String playlistId;

  const PlaylistView({super.key, required this.playlistId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistAsync = ref.watch(playlistDetailProvider(playlistId));
    final theme = Theme.of(context);

    return playlistAsync.when(
      data: (playlist) {
        final tracks = playlist.tracks;
        if (tracks.isEmpty) {
          return const EmptyStateCard(
            icon: Icons.music_note_rounded,
            title: '空歌单',
            subtitle: '添加一些歌曲吧',
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
                  await apiService.removeTrackFromPlaylist(playlistId, track.id);
                  ref.invalidate(playlistDetailProvider(playlistId));
                  SnackBarHelper.showSuccess(context, '已移出歌单');
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