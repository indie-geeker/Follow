import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:follow/core/network/media_url.dart';
import 'package:follow/data/providers/artist_provider.dart';
import 'package:follow/data/providers/track_provider.dart';
import 'package:follow/shared/widgets/smart_track_tile.dart';
import 'package:follow/data/providers/audio_provider.dart';
import 'package:follow/shared/widgets/play_all_tile.dart';
import 'package:follow/shared/widgets/loading/app_content_skeleton.dart';
import 'package:follow/shared/widgets/states/app_state_kind.dart';
import 'package:follow/shared/widgets/states/app_state_view.dart';

@RoutePage()
class ArtistDetailPage extends ConsumerWidget {
  const ArtistDetailPage({@PathParam('id') required this.id, super.key});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artistAsync = ref.watch(artistProvider(id));
    final tracksAsync = ref.watch(artistTracksProvider(id));
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 280,
            flexibleSpace: FlexibleSpaceBar(
              background: artistAsync.when(
                data: (artist) {
                  final coverUri = resolveCoverUri(artist.coverUrl);
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      if (coverUri != null)
                        Image.network(
                          coverUri.toString(),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: theme.colorScheme.primaryContainer,
                            child: Icon(
                              Icons.person,
                              size: 120,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        )
                      else
                        Container(
                          color: theme.colorScheme.primaryContainer,
                          child: Icon(
                            Icons.person,
                            size: 120,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      // Gradient overlay
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.7),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 16,
                        left: 16,
                        right: 16,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              artist.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (artist.bio != null)
                              Text(
                                artist.bio!,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
                loading: () => Container(color: theme.colorScheme.surface),
                error: (_, __) =>
                    Container(color: theme.colorScheme.errorContainer),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            sliver: tracksAsync.when(
              data: (tracks) {
                if (tracks.isEmpty) {
                  return const SliverFillRemaining(
                    child: AppStateView(
                      kind: AppStateKind.emptyLibrary,
                      title: '暂无曲目',
                      description: '这位艺术家暂时没有可播放的曲目。',
                    ),
                  );
                }
                return SliverList.builder(
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
                    return SmartTrackTile(track: track, playlist: tracks);
                  },
                );
              },
              loading: () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: AppContentSkeleton(itemCount: 4),
                ),
              ),
              error: (e, _) => SliverFillRemaining(
                child: AppStateView(
                  kind: AppStateKind.failure,
                  title: '艺术家曲目加载失败',
                  description: '暂时无法读取这位艺术家的曲目。',
                  actionLabel: '重试',
                  onAction: () => ref.invalidate(artistTracksProvider(id)),
                ),
              ),
            ),
          ),
          // Bottom padding for player bar
          const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
        ],
      ),
    );
  }
}
