import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:follow/router/app_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:follow/core/theme/app_theme.dart';
import 'package:follow/data/models/track.dart';
import 'package:follow/data/providers/artist_provider.dart';

class ArtistsTab extends ConsumerWidget {
  const ArtistsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artistsAsync = ref.watch(artistsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return artistsAsync.when(
      data: (artists) {
        if (artists.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.person_outline,
                  size: 64,
                  color: isDark ? LoginColors.textSecondary : theme.colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  '暂无艺术家',
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
              onPressed: () => ref.read(artistsProvider.notifier).refresh(),
              child: const Text('重试'),
            ),
          ],
        ),
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

    return GestureDetector(
      onTap: () {
        context.pushRoute(ArtistDetailRoute(id: artist.id));
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
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: artist.coverUrl != null && artist.coverUrl!.isNotEmpty
                      ? Image.network(
                          artist.coverUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildPlaceholder(initial),
                        )
                      : _buildPlaceholder(initial),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Text(
                    artist.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  if (artist.bio != null && artist.bio!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      artist.bio!,
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
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(String initial) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            LoginColors.gradientStart,
            LoginColors.gradientEnd,
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
