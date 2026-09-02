import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:follow/router/app_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:follow/core/network/media_url.dart';
import 'package:follow/core/theme/follow_theme_tokens.dart';
import 'package:follow/data/models/track.dart';
import 'package:follow/data/providers/artist_provider.dart';
import 'package:follow/shared/widgets/loading/app_content_skeleton.dart';
import 'package:follow/shared/widgets/states/app_state_kind.dart';
import 'package:follow/shared/widgets/states/app_state_view.dart';

class ArtistsTab extends ConsumerWidget {
  const ArtistsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artistsAsync = ref.watch(artistsProvider);

    return artistsAsync.when(
      data: (artists) {
        if (artists.isEmpty) {
          return const AppStateView(
            kind: AppStateKind.emptyLibrary,
            title: '暂无艺术家',
            description: '添加音乐后，艺术家会自动整理在这里。',
          );
        }

        return RefreshIndicator(
          onRefresh: () => ref.read(artistsProvider.notifier).refresh(),
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
              childAspectRatio: 0.8,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: artists.length,
            itemBuilder: (context, index) {
              return _ArtistCard(artist: artists[index]);
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
        title: '艺术家加载失败',
        description: '暂时无法读取艺术家，请稍后重试。',
        actionLabel: '重试',
        onAction: () => ref.read(artistsProvider.notifier).refresh(),
      ),
    );
  }
}

class _ArtistCard extends StatelessWidget {
  final Artist artist;

  const _ArtistCard({required this.artist});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final initial = artist.name.isNotEmpty ? artist.name[0].toUpperCase() : '?';
    final coverUri = resolveCoverUri(artist.coverUrl);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          context.pushRoute(ArtistDetailRoute(id: artist.id));
        },
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
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
                              _buildPlaceholder(context, initial),
                        )
                      : _buildPlaceholder(context, initial),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Text(
                    artist.name,
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
                  if (artist.bio != null && artist.bio!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      artist.bio!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? context.followTokens.textSecondary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

  Widget _buildPlaceholder(BuildContext context, String initial) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            context.followTokens.brandPrimary,
            context.followTokens.background,
          ],
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
