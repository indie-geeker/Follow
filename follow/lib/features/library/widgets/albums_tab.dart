import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:follow/router/app_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:follow/core/network/media_url.dart';
import 'package:follow/core/theme/follow_theme_tokens.dart';
import 'package:follow/data/models/track.dart';
import 'package:follow/data/providers/album_provider.dart';
import 'package:follow/shared/widgets/loading/app_content_skeleton.dart';
import 'package:follow/shared/widgets/states/app_state_kind.dart';
import 'package:follow/shared/widgets/states/app_state_view.dart';

class AlbumsTab extends ConsumerWidget {
  const AlbumsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albumsAsync = ref.watch(albumsProvider);

    return albumsAsync.when(
      data: (albums) {
        if (albums.isEmpty) {
          return const AppStateView(
            kind: AppStateKind.emptyLibrary,
            title: '暂无专辑',
            description: '添加音乐后，专辑会自动整理在这里。',
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
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: AppContentSkeleton(),
      ),
      error: (error, stack) => AppStateView(
        kind: AppStateKind.failure,
        title: '专辑加载失败',
        description: '暂时无法读取专辑，请稍后重试。',
        actionLabel: '重试',
        onAction: () => ref.read(albumsProvider.notifier).refresh(),
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

    final coverUri = resolveCoverUri(album.coverUrl);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          context.pushRoute(AlbumDetailRoute(id: album.id));
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: coverUri != null
                      ? Image.network(
                          coverUri.toString(),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _buildPlaceholder(context),
                        )
                      : _buildPlaceholder(context),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Text(
                    album.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? Colors.white
                          : theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    album.artist?.name ?? '未知艺术家',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? context.followTokens.textSecondary
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
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isDark
                            ? context.followTokens.textSecondary
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

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            context.followTokens.success,
            context.followTokens.auroraCyan,
          ],
        ),
      ),
      child: const Center(
        child: Icon(Icons.album, size: 48, color: Colors.white),
      ),
    );
  }
}
