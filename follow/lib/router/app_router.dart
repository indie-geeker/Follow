import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:follow/core/l10n/l10n.dart';
import 'package:follow/shared/widgets/mini_player.dart';
import 'package:follow/data/providers/audio_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Import actual page implementations
import 'package:follow/features/home/home_page.dart';
import 'package:follow/features/library/library_page.dart';
import 'package:follow/features/search/search_page.dart';
import 'package:follow/features/downloads/downloads_page.dart';
import 'package:follow/features/settings/settings_page.dart';
import 'package:follow/features/auth/login_page.dart';
import 'package:follow/features/player/player_page.dart';

part 'app_router.gr.dart';

@AutoRouterConfig(replaceInRouteName: 'Page|Screen,Route')
class AppRouter extends RootStackRouter {
  @override
  RouteType get defaultRouteType => const RouteType.adaptive();

  @override
  List<AutoRoute> get routes => [
        AutoRoute(page: LoginRoute.page, path: '/login'),
        AutoRoute(
          page: MainShellRoute.page,
          path: '/',
          initial: true,
          guards: [AuthGuard()],
          children: [
            AutoRoute(page: HomeRoute.page, path: 'home', initial: true),
            AutoRoute(page: LibraryRoute.page, path: 'library'),
            AutoRoute(page: SearchRoute.page, path: 'search'),
            AutoRoute(page: DownloadsRoute.page, path: 'downloads'),
            AutoRoute(page: SettingsRoute.page, path: 'settings'),
          ],
        ),
        AutoRoute(page: PlayerRoute.page, path: '/player', guards: [AuthGuard()]),
        AutoRoute(page: PlaylistDetailRoute.page, path: '/playlist/:id', guards: [AuthGuard()]),
        AutoRoute(page: ArtistDetailRoute.page, path: '/artist/:id', guards: [AuthGuard()]),
        AutoRoute(page: AlbumDetailRoute.page, path: '/album/:id', guards: [AuthGuard()]),
      ];
}

class AuthGuard extends AutoRouteGuard {
  @override
  void onNavigation(NavigationResolver resolver, StackRouter router) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    
    if (token != null && token.isNotEmpty) {
      resolver.next(true);
    } else {
      resolver.redirectUntil(const LoginRoute());
    }
  }
}

// ============ Responsive Main Shell ============

@RoutePage()
class MainShellPage extends ConsumerStatefulWidget {
  const MainShellPage({super.key});

  @override
  ConsumerState<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends ConsumerState<MainShellPage> {
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 800;

    if (isDesktop) {
      return _DesktopShell();
    } else {
      return _MobileShell();
    }
  }
}

// ============ Mobile Layout (Bottom Navigation) ============

class _MobileShell extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final currentTrack = ref.watch(currentTrackProvider);

    return AutoTabsScaffold(
      routes: const [
        HomeRoute(),
        LibraryRoute(),
        SearchRoute(),
        DownloadsRoute(),
        SettingsRoute(),
      ],
      bottomNavigationBuilder: (context, tabsRouter) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (currentTrack != null)
              MiniPlayer(
                onTap: () => context.router.push(const PlayerRoute()),
              ),
            NavigationBar(
              selectedIndex: tabsRouter.activeIndex,
              onDestinationSelected: tabsRouter.setActiveIndex,
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.home_outlined),
                  selectedIcon: const Icon(Icons.home),
                  label: l10n.home,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.library_music_outlined),
                  selectedIcon: const Icon(Icons.library_music),
                  label: l10n.library,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.search_outlined),
                  selectedIcon: const Icon(Icons.search),
                  label: l10n.search,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.download_outlined),
                  selectedIcon: const Icon(Icons.download),
                  label: l10n.downloads,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.settings_outlined),
                  selectedIcon: const Icon(Icons.settings),
                  label: l10n.settings,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

// ============ Desktop Layout (Sidebar Navigation) ============

class _DesktopShell extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final currentTrack = ref.watch(currentTrackProvider);
    final width = MediaQuery.of(context).size.width;
    final isExpanded = width >= 1200;

    return AutoTabsRouter(
      routes: const [
        HomeRoute(),
        LibraryRoute(),
        SearchRoute(),
        DownloadsRoute(),
        SettingsRoute(),
      ],
      builder: (context, child) {
        final tabsRouter = AutoTabsRouter.of(context);

        return Scaffold(
          body: Row(
            children: [
              // Sidebar
              NavigationRail(
                extended: isExpanded,
                minExtendedWidth: 200,
                selectedIndex: tabsRouter.activeIndex,
                onDestinationSelected: tabsRouter.setActiveIndex,
                leading: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.music_note,
                        color: theme.colorScheme.primary,
                        size: 32,
                      ),
                      if (isExpanded) ...[
                        const SizedBox(width: 8),
                        Text(
                          'Follow',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                destinations: [
                  NavigationRailDestination(
                    icon: const Icon(Icons.home_outlined),
                    selectedIcon: const Icon(Icons.home),
                    label: Text(l10n.home),
                  ),
                  NavigationRailDestination(
                    icon: const Icon(Icons.library_music_outlined),
                    selectedIcon: const Icon(Icons.library_music),
                    label: Text(l10n.library),
                  ),
                  NavigationRailDestination(
                    icon: const Icon(Icons.search_outlined),
                    selectedIcon: const Icon(Icons.search),
                    label: Text(l10n.search),
                  ),
                  NavigationRailDestination(
                    icon: const Icon(Icons.download_outlined),
                    selectedIcon: const Icon(Icons.download),
                    label: Text(l10n.downloads),
                  ),
                  NavigationRailDestination(
                    icon: const Icon(Icons.settings_outlined),
                    selectedIcon: const Icon(Icons.settings),
                    label: Text(l10n.settings),
                  ),
                ],
              ),
              // Vertical divider
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: theme.colorScheme.outlineVariant,
              ),
              // Main content
              Expanded(
                child: Column(
                  children: [
                    Expanded(child: child),
                    // Bottom player bar for desktop
                    if (currentTrack != null)
                      _DesktopPlayerBar(currentTrack: currentTrack),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ============ Desktop Player Bar ============

class _DesktopPlayerBar extends ConsumerWidget {
  final dynamic currentTrack;

  const _DesktopPlayerBar({required this.currentTrack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isPlayingAsync = ref.watch(isPlayingProvider);
    final positionAsync = ref.watch(playerPositionProvider);
    final durationAsync = ref.watch(playerDurationProvider);
    final audioService = ref.watch(audioPlayerServiceProvider);

    final isPlaying = isPlayingAsync.when(
      data: (v) => v,
      loading: () => false,
      error: (_, __) => false,
    );
    final position = positionAsync.when(
      data: (v) => v ?? Duration.zero,
      loading: () => Duration.zero,
      error: (_, __) => Duration.zero,
    );
    final duration = durationAsync.when(
      data: (v) => v ?? const Duration(seconds: 1),
      loading: () => const Duration(seconds: 1),
      error: (_, __) => const Duration(seconds: 1),
    );

    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          // Track info
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // Cover
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.music_note,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Info
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentTrack.title,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          currentTrack.artist?.name ?? '',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Controls
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Control buttons
                  SizedBox(
                    height: 32,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.shuffle),
                          iconSize: 18,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 28,
                            maxHeight: 32,
                          ),
                          onPressed: () {},
                        ),
                        IconButton(
                          icon: const Icon(Icons.skip_previous_rounded),
                          iconSize: 24,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                            maxHeight: 32,
                          ),
                          onPressed: () {},
                        ),
                        const SizedBox(width: 4),
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: Icon(
                              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              color: theme.colorScheme.onPrimary,
                            ),
                            iconSize: 22,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 36,
                              minHeight: 36,
                            ),
                            onPressed: () {
                              if (isPlaying) {
                                audioService.pause();
                              } else {
                                audioService.play();
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.skip_next_rounded),
                          iconSize: 24,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                            maxHeight: 32,
                          ),
                          onPressed: () {},
                        ),
                        IconButton(
                          icon: const Icon(Icons.repeat),
                          iconSize: 18,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 28,
                            maxHeight: 32,
                          ),
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Progress bar
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Text(
                            _formatDuration(position),
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SliderTheme(
                              data: SliderThemeData(
                                trackHeight: 2,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 4,
                                ),
                                overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 12,
                                ),
                              ),
                              child: Slider(
                                value: position.inMilliseconds.toDouble().clamp(
                                  0,
                                  duration.inMilliseconds.toDouble(),
                                ),
                                max: duration.inMilliseconds.toDouble(),
                                onChanged: (value) {
                                  audioService.seek(
                                    Duration(milliseconds: value.toInt()),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatDuration(duration),
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Volume & actions
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.favorite_border),
                    iconSize: 18,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: const Icon(Icons.lyrics),
                    iconSize: 18,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    onPressed: () {},
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.volume_up, size: 18),
                  const SizedBox(width: 4),
                  Flexible(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 80),
                      child: SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 2,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 4,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 12,
                          ),
                        ),
                        child: Slider(
                          value: 1.0,
                          onChanged: (value) {},
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final mins = d.inMinutes;
    final secs = d.inSeconds % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }
}

// ============ Detail Pages ============

@RoutePage()
class PlaylistDetailPage extends StatelessWidget {
  const PlaylistDetailPage({@PathParam('id') required this.id, super.key});
  final String id;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('播放列表')),
        body: Center(child: Text('Playlist $id')),
      );
}

@RoutePage()
class ArtistDetailPage extends StatelessWidget {
  const ArtistDetailPage({@PathParam('id') required this.id, super.key});
  final String id;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('艺术家')),
        body: Center(child: Text('Artist $id')),
      );
}

@RoutePage()
class AlbumDetailPage extends StatelessWidget {
  const AlbumDetailPage({@PathParam('id') required this.id, super.key});
  final String id;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('专辑')),
        body: Center(child: Text('Album $id')),
      );
}
