import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:follow/core/l10n/l10n.dart';
import 'package:follow/core/theme/follow_theme_tokens.dart';
import 'package:follow/core/theme/player_palette.dart';
import 'package:follow/core/theme/player_palette_provider.dart';
import 'package:follow/data/providers/auth_provider.dart';
import 'package:follow/data/providers/history_provider.dart';
import 'package:follow/data/providers/playlist_provider.dart';
import 'package:follow/features/home/widgets/home_aurora_header.dart';
import 'package:follow/features/home/views/favorites_view.dart';
import 'package:follow/features/home/views/playlist_view.dart';
import 'package:follow/features/home/views/recently_played_view.dart';
import 'package:follow/router/app_router.dart';
import 'package:follow/shared/widgets/app_logo.dart';
import 'package:follow/shared/widgets/create_playlist_dialog.dart';
import 'package:follow/shared/widgets/surfaces/aurora_background.dart';
import 'package:follow/shared/widgets/user_avatar.dart';

class HomeScrollSafeArea extends StatelessWidget {
  const HomeScrollSafeArea({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
        statusBarBrightness: brightness,
      ),
      child: child,
    );
  }
}

const homeHeaderFlexibleSpaceKey = ValueKey(
  'home-collapsing-header-flexible-space',
);
const homePinnedTabSurfaceKey = ValueKey('home-pinned-tab-surface');

class HomeHeaderSnapScrollPhysics extends ScrollPhysics {
  const HomeHeaderSnapScrollPhysics({
    required this.collapseRange,
    this.snapThreshold = 0.4,
    super.parent,
  });

  final double collapseRange;
  final double snapThreshold;

  @override
  HomeHeaderSnapScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return HomeHeaderSnapScrollPhysics(
      collapseRange: collapseRange,
      snapThreshold: snapThreshold,
      parent: buildParent(ancestor),
    );
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    final pixels = position.pixels;
    if (position.outOfRange ||
        collapseRange <= 0 ||
        pixels <= 0 ||
        pixels >= collapseRange) {
      return super.createBallisticSimulation(position, velocity);
    }

    final tolerance = toleranceFor(position);
    final target = velocity.abs() > tolerance.velocity * 24
        ? velocity > 0
              ? collapseRange
              : 0.0
        : pixels < collapseRange * snapThreshold
        ? 0.0
        : collapseRange;

    return ScrollSpringSimulation(
      spring,
      pixels,
      target,
      velocity,
      tolerance: tolerance,
    );
  }
}

class HomeCollapsingHeader extends StatelessWidget {
  const HomeCollapsingHeader({
    required this.expandedHeight,
    required this.heroBuilder,
    required this.tabs,
    super.key,
  });

  static const collapsedHeight = 48.0;

  final double expandedHeight;
  final Widget Function(double collapseProgress) heroBuilder;
  final Widget tabs;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final effectiveExpandedHeight = expandedHeight + topInset;
    final effectiveCollapsedHeight = collapsedHeight + topInset;
    return SliverAppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: 0,
      expandedHeight: expandedHeight,
      pinned: true,
      floating: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final settings = context
              .dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
          final currentExtent =
              settings?.currentExtent ?? constraints.maxHeight;
          final range = effectiveExpandedHeight - effectiveCollapsedHeight;
          final progress = range <= 0
              ? 1.0
              : ((effectiveExpandedHeight - currentExtent) / range).clamp(
                  0.0,
                  1.0,
                );
          return SizedBox.expand(
            key: homeHeaderFlexibleSpaceKey,
            child: heroBuilder(progress),
          );
        },
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(collapsedHeight),
        child: _PinnedTabSurface(child: tabs),
      ),
    );
  }
}

class _PinnedTabSurface extends StatelessWidget {
  const _PinnedTabSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final settings = context
        .dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
    final range = (settings?.maxExtent ?? 1) - (settings?.minExtent ?? 0);
    final progress = range <= 0
        ? 1.0
        : (((settings?.maxExtent ?? 1) - (settings?.currentExtent ?? 1)) /
                  range)
              .clamp(0.0, 1.0);
    final glassProgress = Curves.easeOut.transform(
      ((progress - 0.62) / 0.38).clamp(0.0, 1.0),
    );
    final tokens = context.followTokens;

    return DecoratedBox(
      key: homePinnedTabSurfaceKey,
      decoration: BoxDecoration(
        color: tokens.surface.withValues(alpha: 0.82 * glassProgress),
        border: Border(
          bottom: BorderSide(
            color: tokens.textPrimary.withValues(alpha: 0.08 * glassProgress),
            width: 0.5,
          ),
        ),
      ),
      child: SizedBox(
        height: HomeCollapsingHeader.collapsedHeight,
        child: child,
      ),
    );
  }
}

@RoutePage()
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  int _tabCount = 2; // Initial: Recently Played + Favorites

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabCount, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _updateTabController(int newCount) {
    if (newCount == _tabCount) return;
    final oldIndex = _tabController.index;
    _tabController.dispose();
    _tabController = TabController(
      length: newCount,
      vsync: this,
      initialIndex: oldIndex >= newCount ? 0 : oldIndex,
    );
    _tabCount = newCount;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    final playlistsAsync = ref.watch(playlistsProvider);
    final recentTracks = ref.watch(historyProvider).value;
    final headerTrack = recentTracks == null || recentTracks.isEmpty
        ? null
        : recentTracks.first;
    final headerPaletteAsync = ref.watch(
      playerPaletteProvider(
        PlayerPaletteRequest.fromTrack(headerTrack, theme.brightness),
      ),
    );
    final headerPalette =
        headerPaletteAsync.value ??
        PlayerPalette.fallback(
          brightness: theme.brightness,
          tokens: context.followTokens,
        );

    return playlistsAsync.when(
      data: (playlists) {
        final totalTabs = 2 + playlists.length;
        _updateTabController(totalTabs); // Ensure controller matches data

        return Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          body: AuroraBackground(
            child: HomeScrollSafeArea(
              child: NestedScrollView(
                physics: const HomeHeaderSnapScrollPhysics(collapseRange: 160),
                headerSliverBuilder: (context, innerBoxIsScrolled) {
                  return [
                    HomeCollapsingHeader(
                      expandedHeight: 208,
                      heroBuilder: (collapseProgress) => HomeAuroraHeader(
                        palette: headerPalette,
                        usesBrandFallback:
                            headerTrack == null ||
                            headerPaletteAsync.value == null,
                        collapseProgress: collapseProgress,
                        title: user != null ? '你好, ${user.username}' : '欢迎',
                        subtitle: '开始享受音乐吧',
                        leading: const AppLogo(),
                        trailing: user == null
                            ? const SizedBox.shrink()
                            : UserAvatar(user: user),
                      ),
                      tabs: Row(
                        children: [
                          Expanded(
                            child: TabBar(
                              controller: _tabController,
                              isScrollable: true,
                              tabAlignment: TabAlignment.start,
                              dividerColor: Colors.transparent,
                              indicatorColor: context.followTokens.brandPrimary,
                              labelColor: theme.colorScheme.primary,
                              unselectedLabelColor:
                                  context.followTokens.textSecondary,
                              tabs: [
                                const Tab(text: '最近播放'),
                                Tab(text: l10n.get('favorites')),
                                ...playlists.map((p) => Tab(text: p.name)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add),
                            tooltip: '新建歌单',
                            onPressed: () => showCreatePlaylistDialog(
                              context,
                              onCreate: (name) => ref
                                  .read(playlistsProvider.notifier)
                                  .create(name),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ),
                  ];
                },
                body: TabBarView(
                  controller: _tabController,
                  children: [
                    RecentlyPlayedView(
                      onBrowseLibrary: () {
                        AutoTabsRouter.of(
                          context,
                        ).navigate(const LibraryRoute());
                      },
                    ),
                    const FavoritesView(),
                    ...playlists.map((p) => PlaylistView(playlistId: p.id)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, s) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }
}
