import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:follow/core/theme/follow_theme_tokens.dart';
import 'package:follow/data/models/track.dart';
import 'package:follow/data/providers/playlist_provider.dart';
import 'package:follow/data/providers/track_provider.dart';
import 'package:follow/data/services/api/api_service.dart';
import 'package:follow/shared/widgets/create_playlist_dialog.dart';

class AddToPlaylistDialog extends ConsumerWidget {
  final Track track;

  const AddToPlaylistDialog({super.key, required this.track});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistsAsync = ref.watch(playlistsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark
          ? context.followTokens.surface
          : theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        constraints: const BoxConstraints(maxHeight: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '添加到歌单',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? Colors.white
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭',
                    icon: Icon(
                      Icons.close_rounded,
                      color: isDark
                          ? Colors.white70
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  key: const ValueKey('create-playlist-from-add-dialog'),
                  onPressed: () => showCreatePlaylistDialog(
                    context,
                    onCreate: (name) =>
                        ref.read(playlistsProvider.notifier).create(name),
                  ),
                  icon: const Icon(Icons.playlist_add_rounded),
                  label: const Text('新建歌单'),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Divider(color: theme.colorScheme.outlineVariant),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      '选择保存位置',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Divider(color: theme.colorScheme.outlineVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Flexible(
              child: playlistsAsync.when(
                data: (playlists) {
                  final editablePlaylists = playlists
                      .where((playlist) => playlist.canEdit)
                      .toList(growable: false);
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: editablePlaylists.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.favorite_rounded,
                              color: Colors.red,
                            ),
                          ),
                          title: Text(
                            '我的收藏',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white
                                  : theme.colorScheme.onSurface,
                            ),
                          ),
                          onTap: () async {
                            try {
                              final apiService = ApiService();
                              await apiService.addToFavorites(track.id);
                              ref.invalidate(favoritesProvider);
                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('已添加到收藏'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('添加失败: $e'),
                                    backgroundColor: theme.colorScheme.error,
                                  ),
                                );
                              }
                            }
                          },
                        );
                      }

                      final playlist = editablePlaylists[index - 1];
                      return ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isDark
                                ? context.followTokens.brandPrimary.withValues(
                                    alpha: 0.2,
                                  )
                                : theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.queue_music_rounded,
                            color: isDark
                                ? context.followTokens.brandPrimary
                                : theme.colorScheme.primary,
                          ),
                        ),
                        title: Text(
                          playlist.name,
                          style: TextStyle(
                            color: isDark
                                ? Colors.white
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                        onTap: () async {
                          try {
                            await ref
                                .read(playlistsProvider.notifier)
                                .addTrack(playlist.id, track.id);
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('已添加到 ${playlist.name}'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('添加失败: $e'),
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
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('加载失败: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
