import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:follow/core/theme/app_theme.dart';
import 'package:follow/data/models/track.dart';
import 'package:follow/data/providers/playlist_provider.dart';
import 'package:follow/data/providers/track_provider.dart';
import 'package:follow/data/services/api/api_service.dart';

class AddToPlaylistDialog extends ConsumerWidget {
  final Track track;

  const AddToPlaylistDialog({super.key, required this.track});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistsAsync = ref.watch(playlistsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? LoginColors.gradientMid1 : theme.colorScheme.surface,
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
                      color: isDark ? Colors.white : theme.colorScheme.onSurface,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: isDark ? Colors.white70 : theme.colorScheme.onSurfaceVariant),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: playlistsAsync.when(
                data: (playlists) {
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: playlists.length + 1,
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
                              color: isDark ? Colors.white : theme.colorScheme.onSurface,
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
                      
                      final playlist = playlists[index - 1];
                      return ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isDark ? LoginColors.accentPurple.withValues(alpha: 0.2) : theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.queue_music_rounded,
                            color: isDark ? LoginColors.accentPurple : theme.colorScheme.primary,
                          ),
                        ),
                        title: Text(
                          playlist.name,
                          style: TextStyle(
                            color: isDark ? Colors.white : theme.colorScheme.onSurface,
                          ),
                        ),
                        onTap: () async {
                           try {
                            await ref.read(playlistsProvider.notifier).addTrack(playlist.id, track.id);
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
