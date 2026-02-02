import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:follow/router/app_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:follow/core/theme/app_theme.dart';
import 'package:follow/data/models/track.dart';
import 'package:follow/data/providers/album_provider.dart';

class AlbumsTab extends ConsumerWidget {
  const AlbumsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albumsAsync = ref.watch(albumsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return albumsAsync.when(
      data: (albums) {
        if (albums.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.album_outlined,
                  size: 64,
                  color: isDark ? LoginColors.textSecondary : theme.colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  '暂无专辑',
                  style: isDark
                      ? const TextStyle(
                          color: LoginColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        )
                      : theme.textTheme.titleLarge,
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => ref.read(albumsProvider.notifier).refresh(),
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
              childAspectRatio: 0.75, // Slightly taller for two lines of text
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: albums.length,
            itemBuilder: (context, index) {
              return _AlbumCard(album: albums[index]);
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('加载失败: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.read(albumsProvider.notifier).refresh(),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlbumCard extends StatelessWidget {
  final Album album;

  const _AlbumCard({required this.album});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Use music note icon as placeholder for albums
    final hasCover = album.coverUrl != null && album.coverUrl!.isNotEmpty;

    return GestureDetector(
      onTap: () {
        context.pushRoute(AlbumDetailRoute(id: album.id));
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? LoginColors.cardBackground
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: isDark
              ? Border.all(color: LoginColors.cardBorder.withOpacity(0.5))
              : null,
          boxShadow: [
             if (isDark)
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: hasCover
                      ? Image.network(
                          album.coverUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildPlaceholder(),
                        )
                      : _buildPlaceholder(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Text(
                    album.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    album.artist?.name ?? '未知艺术家',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? LoginColors.textSecondary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  if (album.year != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${album.year}',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark
                            ? LoginColors.textHint
                            : theme.colorScheme.outline,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF43E97B),
            Color(0xFF38F9D7),
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.album,
          size: 48,
          color: Colors.white,
        ),
      ),
    );
  }
}
