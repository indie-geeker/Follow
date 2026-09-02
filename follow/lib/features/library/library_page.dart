import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:follow/core/l10n/l10n.dart';
import 'package:follow/core/theme/follow_theme_tokens.dart';
import 'package:follow/data/providers/track_provider.dart';
import 'package:follow/shared/widgets/smart_track_tile.dart';
import 'package:follow/features/library/widgets/artists_tab.dart';
import 'package:follow/features/library/widgets/albums_tab.dart';
import 'package:follow/features/library/widgets/library_search_box.dart';
import 'package:follow/router/app_router.dart';
import 'package:follow/router/mobile_navigation.dart';
import 'package:follow/shared/widgets/loading/app_content_skeleton.dart';
import 'package:follow/shared/widgets/section_header.dart';
import 'package:follow/shared/widgets/states/app_state_kind.dart';
import 'package:follow/shared/widgets/states/app_state_view.dart';
import 'package:follow/shared/widgets/surfaces/aurora_background.dart';
import 'package:follow/shared/widgets/surfaces/glass_panel.dart';

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
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: AuroraBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Custom header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: SectionHeader(
                        title: l10n.library,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                    if (isDesktop)
                      const LibrarySearchBox()
                    else
                      _LibrarySearchButton(tooltip: l10n.search),
                  ],
                ),
              ),

              // Tab bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GlassPanel(
                  tier: GlassTier.standard,
                  borderRadius: BorderRadius.circular(
                    context.followTokens.radiusInput,
                  ),
                  child: TabBar(
                    controller: _tabController,
                    labelPadding: EdgeInsets.zero,
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    indicator: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          context.followTokens.brandPrimary,
                          context.followTokens.brandSecondary,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: isDark
                        ? context.followTokens.textSecondary
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
              ? context.followTokens.surface
              : theme.colorScheme.surfaceContainerHighest,
          foregroundColor: isDark
              ? context.followTokens.brandPrimary
              : theme.colorScheme.primary,
          side: isDark
              ? BorderSide(color: context.followTokens.glassStandard.border)
              : null,
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
    return tracksAsync.when(
      data: (tracks) {
        if (tracks.isEmpty) {
          return const AppStateView(
            kind: AppStateKind.emptyLibrary,
            title: '暂无曲目',
            description: '添加一些音乐到库中',
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
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: AppContentSkeleton(),
      ),
      error: (e, _) => AppStateView(
        kind: AppStateKind.failure,
        title: '音乐库加载失败',
        description: '暂时无法读取音乐库，请检查网络后重试。',
        actionLabel: '重试',
        onAction: () => ref.read(tracksProvider.notifier).refresh(),
      ),
    );
  }
}
