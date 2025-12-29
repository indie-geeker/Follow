import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:follow/core/l10n/l10n.dart';
import 'package:follow/data/providers/track_provider.dart';
import 'package:follow/data/providers/audio_provider.dart';
import 'package:follow/shared/widgets/track_tile.dart';

@RoutePage()
class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.library),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l10n.tracks),
            Tab(text: l10n.artists),
            Tab(text: l10n.albums),
            Tab(text: l10n.playlists),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _TracksTab(),
          _ArtistsTab(),
          _AlbumsTab(),
          _PlaylistsTab(),
        ],
      ),
    );
  }
}

class _TracksTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracksAsync = ref.watch(tracksProvider);
    final currentTrack = ref.watch(currentTrackProvider);

    return tracksAsync.when(
      data: (tracks) {
        if (tracks.isEmpty) {
          return const Center(child: Text('暂无曲目'));
        }
        return RefreshIndicator(
          onRefresh: () => ref.read(tracksProvider.notifier).refresh(),
          child: ListView.builder(
            itemCount: tracks.length,
            itemBuilder: (context, index) {
              final track = tracks[index];
              return TrackTile(
                track: track,
                isPlaying: currentTrack?.id == track.id,
                onTap: () {
                  ref.read(currentTrackProvider.notifier).setTrack(track);
                  ref.read(playQueueProvider.notifier).setQueue(tracks);
                  ref.read(audioPlayerServiceProvider).playTrack(track);
                },
                onMorePressed: () => _showTrackOptions(context, track),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('加载失败: $e')),
    );
  }

  void _showTrackOptions(BuildContext context, track) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.favorite_border),
              title: const Text('添加到收藏'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add),
              title: const Text('添加到播放列表'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('下载'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArtistsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('艺术家列表'));
  }
}

class _AlbumsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('专辑列表'));
  }
}

class _PlaylistsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('播放列表'));
  }
}
