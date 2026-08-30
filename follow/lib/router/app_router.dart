import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:follow/core/l10n/l10n.dart';
import 'package:follow/shared/widgets/mini_player.dart';
import 'package:follow/shared/widgets/desktop_player_bar.dart';
import 'package:follow/data/providers/audio_provider.dart';
import 'package:follow/data/services/api/api_client.dart';
import 'package:follow/data/providers/lyrics_provider.dart';
import 'package:follow/features/player/lyrics_overlay.dart';
import 'package:follow/router/mobile_navigation.dart';

// Import actual page implementations
import 'package:follow/features/home/home_page.dart';
import 'package:follow/features/library/library_page.dart';
import 'package:follow/features/search/search_page.dart';
import 'package:follow/features/downloads/downloads_page.dart';
import 'package:follow/features/settings/settings_page.dart';
import 'package:follow/features/auth/login_page.dart';
import 'package:follow/features/player/player_page.dart';
import 'package:follow/features/library/album_detail_page.dart';
import 'package:follow/features/library/artist_detail_page.dart';

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
        AutoRoute(page: DownloadsRoute.page, path: 'downloads'),
        AutoRoute(page: SettingsRoute.page, path: 'settings'),
      ],
    ),
    AutoRoute(page: SearchRoute.page, path: '/search', guards: [AuthGuard()]),
    AutoRoute(page: PlayerRoute.page, path: '/player', guards: [AuthGuard()]),
    AutoRoute(
      page: PlaylistDetailRoute.page,
      path: '/playlist/:id',
      guards: [AuthGuard()],
    ),
    AutoRoute(
      page: ArtistDetailRoute.page,
      path: '/artist/:id',
      guards: [AuthGuard()],
    ),
    AutoRoute(
      page: AlbumDetailRoute.page,
      path: '/album/:id',
      guards: [AuthGuard()],
    ),
  ];
}

class AuthGuard extends AutoRouteGuard {
  @override
  void onNavigation(NavigationResolver resolver, StackRouter router) async {
    final tokens = await ApiClient.tokenStore.readTokens();

    if (tokens != null && tokens.accessToken.isNotEmpty) {
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
    final isDesktop = usesDesktopNavigation(width);

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
      routes: [
        for (final destination in mobileNavigationDestinations)
          _routeForDestination(destination),
      ],
      bottomNavigationBuilder: (context, tabsRouter) {
        return SafeArea(
          top: false,
          child: Column(
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
                  for (final destination in mobileNavigationDestinations)
                    NavigationDestination(
                      icon: Icon(_iconForDestination(destination)),
                      selectedIcon: Icon(
                        _selectedIconForDestination(destination),
                      ),
                      label: _labelForDestination(destination, l10n),
                    ),
                ],
              ),
            ],
          ),
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
      routes: [
        for (final destination in mobileNavigationDestinations)
          _routeForDestination(destination),
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
                onDestinationSelected: (index) {
                  // Hide lyrics overlay when navigating
                  ref.read(lyricsOverlayVisibleProvider.notifier).hide();
                  tabsRouter.setActiveIndex(index);
                },
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
                  for (final destination in mobileNavigationDestinations)
                    NavigationRailDestination(
                      icon: Icon(_iconForDestination(destination)),
                      selectedIcon: Icon(
                        _selectedIconForDestination(destination),
                      ),
                      label: Text(_labelForDestination(destination, l10n)),
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
                child: Stack(
                  children: [
                    Column(
                      children: [
                        Expanded(child: child),
                        // Bottom player bar for desktop
                        if (currentTrack != null)
                          DesktopPlayerBar(currentTrack: currentTrack),
                      ],
                    ),
                    // Lyrics overlay
                    Consumer(
                      builder: (context, ref, _) {
                        final showOverlay = ref.watch(
                          lyricsOverlayVisibleProvider,
                        );
                        if (!showOverlay) return const SizedBox.shrink();
                        return LyricsOverlay(
                          onClose: () {
                            ref
                                .read(lyricsOverlayVisibleProvider.notifier)
                                .hide();
                          },
                        );
                      },
                    ),
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

PageRouteInfo<void> _routeForDestination(
  MobileNavigationDestination destination,
) {
  return switch (destination) {
    MobileNavigationDestination.home => const HomeRoute(),
    MobileNavigationDestination.library => const LibraryRoute(),
    MobileNavigationDestination.downloads => const DownloadsRoute(),
    MobileNavigationDestination.settings => const SettingsRoute(),
  };
}

IconData _iconForDestination(MobileNavigationDestination destination) {
  return switch (destination) {
    MobileNavigationDestination.home => Icons.home_outlined,
    MobileNavigationDestination.library => Icons.library_music_outlined,
    MobileNavigationDestination.downloads => Icons.download_outlined,
    MobileNavigationDestination.settings => Icons.settings_outlined,
  };
}

IconData _selectedIconForDestination(MobileNavigationDestination destination) {
  return switch (destination) {
    MobileNavigationDestination.home => Icons.home,
    MobileNavigationDestination.library => Icons.library_music,
    MobileNavigationDestination.downloads => Icons.download,
    MobileNavigationDestination.settings => Icons.settings,
  };
}

String _labelForDestination(
  MobileNavigationDestination destination,
  AppLocalizations l10n,
) {
  return switch (destination) {
    MobileNavigationDestination.home => l10n.home,
    MobileNavigationDestination.library => l10n.library,
    MobileNavigationDestination.downloads => l10n.downloads,
    MobileNavigationDestination.settings => l10n.settings,
  };
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
