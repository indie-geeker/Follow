import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:follow/core/l10n/l10n.dart';
import 'package:follow/core/theme/app_theme.dart';
import 'package:follow/data/providers/track_provider.dart';
import 'package:follow/shared/widgets/smart_track_tile.dart';
import 'package:follow/features/library/widgets/artists_tab.dart';
import 'package:follow/features/library/widgets/albums_tab.dart';
import 'package:follow/features/library/widgets/library_search_box.dart';
import 'package:follow/router/app_router.dart';
import 'package:follow/router/mobile_navigation.dart';

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
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isDesktop = usesDesktopNavigation(MediaQuery.sizeOf(context).width);

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Full-screen gradient background
          if (isDark)
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    LoginColors.gradientEnd,
                    LoginColors.gradientMid2,
                    LoginColors.gradientMid1,
                    LoginColors.gradientStart,
                  ],
                ),
              ),
            ),

          // Content
          SafeArea(
            child: Column(
              children: [
                // Custom header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Row(
                    children: [
                      Text(
                        l10n.library,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? Colors.white
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                      const Spacer(),
                      if (isDesktop)
                        const LibrarySearchBox()
                      else
                        _LibrarySearchButton(tooltip: l10n.search),
                    ],
                  ),
                ),

                // Tab bar
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? LoginColors.cardBackground
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: isDark
                        ? Border.all(color: LoginColors.cardBorder)
                        : null,
                  ),
                  child: TabBar(
                    controller: _tabController,
                    labelPadding: EdgeInsets.zero,
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    indicator: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          LoginColors.accentPurple,
                          LoginColors.accentPink,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: isDark
                        ? LoginColors.textSecondary
                        : theme.colorScheme.onSurfaceVariant,
                    labelStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    tabs: [
                      Tab(text: l10n.tracks),
                      Tab(text: l10n.artists),
                      Tab(text: l10n.albums),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Tab content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _TracksTab(),
                      const ArtistsTab(),
                      const AlbumsTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LibrarySearchButton extends StatelessWidget {
  const _LibrarySearchButton({required this.tooltip});

  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SizedBox.square(
      dimension: 48,
      child: IconButton(
        tooltip: tooltip,
        onPressed: () {
          context.router.root.push(const SearchRoute());
        },
        style: IconButton.styleFrom(
          backgroundColor: isDark
              ? LoginColors.cardBackground
              : theme.colorScheme.surfaceContainerHighest,
          foregroundColor: isDark
              ? LoginColors.accentPurple
              : theme.colorScheme.primary,
          side: isDark ? const BorderSide(color: LoginColors.cardBorder) : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: const Icon(Icons.search_rounded),
      ),
    );
  }
}

class _TracksTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracksAsync = ref.watch(tracksProvider);
    final theme = Theme.of(context);

    return tracksAsync.when(
      data: (tracks) {
        if (tracks.isEmpty) {
          return _PlaceholderTab(
            icon: Icons.music_note_outlined,
            title: '暂无曲目',
            subtitle: '添加一些音乐到库中',
          );
        }
        final notifier = ref.read(tracksProvider.notifier);
        final hasMore = notifier.hasMore;
        return NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification.metrics.axis == Axis.vertical &&
                notification.metrics.extentAfter < 400 &&
                hasMore) {
              notifier.loadMore();
            }
            return false;
          },
          child: RefreshIndicator(
            onRefresh: notifier.refresh,
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 100),
              itemCount: tracks.length + (hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == tracks.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }
                final track = tracks[index];
                return SmartTrackTile(track: track, playlist: tracks);
              },
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text('加载失败: $e', style: TextStyle(color: theme.colorScheme.error)),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderTab extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _PlaceholderTab({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  LoginColors.accentPurple.withValues(alpha: 0.2),
                  LoginColors.accentPink.withValues(alpha: 0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              icon,
              size: 40,
              color: isDark
                  ? LoginColors.accentPurple
                  : theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: isDark
                  ? LoginColors.textSecondary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
