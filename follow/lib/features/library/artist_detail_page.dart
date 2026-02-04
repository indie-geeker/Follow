import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:follow/data/providers/artist_provider.dart';
import 'package:follow/data/providers/track_provider.dart';
import 'package:follow/shared/widgets/smart_track_tile.dart';
import 'package:follow/data/providers/audio_provider.dart';
import 'package:follow/shared/widgets/play_all_tile.dart';

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
                data: (artist) => Stack(
                  fit: StackFit.expand,
                  children: [
                    if (artist.coverUrl != null)
                      Image.network(
                        artist.coverUrl!,
                        fit: BoxFit.cover,
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
                ),
                loading: () => Container(color: theme.colorScheme.surface),
                error: (_, __) => Container(color: theme.colorScheme.errorContainer),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            sliver: tracksAsync.when(
              data: (tracks) {
                if (tracks.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Text('暂无曲目'),
                      ),
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
                    final track = tracks[index -1];
                    return SmartTrackTile(
                      track: track,
                      playlist: tracks,
                    );
                  },
                );
              },
              loading: () => const SliverToBoxAdapter(
                child: Center(child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                )),
              ),
              error: (e, _) => SliverToBoxAdapter(
                child: Center(child: Text('加载失败: $e')),
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
