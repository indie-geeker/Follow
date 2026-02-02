import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:follow/core/l10n/l10n.dart';
import 'package:follow/core/theme/app_theme.dart';
import 'package:follow/data/providers/auth_provider.dart';
import 'package:follow/data/providers/playlist_provider.dart';
import 'package:follow/features/home/views/favorites_view.dart';
import 'package:follow/features/home/views/playlist_view.dart';
import 'package:follow/features/home/views/recently_played_view.dart';

@RoutePage()
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> with TickerProviderStateMixin {
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
    final isDark = theme.brightness == Brightness.dark;
    final user = ref.watch(currentUserProvider);
    final playlistsAsync = ref.watch(playlistsProvider);

    return playlistsAsync.when(
      data: (playlists) {
        final totalTabs = 2 + playlists.length;
        _updateTabController(totalTabs); // Ensure controller matches data

        return Scaffold(
          extendBodyBehindAppBar: true,
          body: Stack(
            children: [
              // Background
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
              NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) {
                  return [
                    // Top Bar (Logo + User)
                    SliverToBoxAdapter(
                      child: SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildLogo(isDark, theme),
                              if (user != null) _buildUserAvatar(user, isDark, theme),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Welcome Text
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user != null ? '你好, ${user.username}' : '欢迎',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '开始享受音乐吧',
                              style: TextStyle(
                                fontSize: 15,
                                color: isDark
                                    ? LoginColors.textSecondary
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Sticky Tabs
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _StickyTabBarDelegate(
                        child: Container(
                          color: isDark 
                              ? LoginColors.gradientEnd.withValues(alpha: 0.95) 
                              : theme.scaffoldBackgroundColor.withValues(alpha: 0.95),
                          child: Row(
                            children: [
                              Expanded(
                                child: TabBar(
                                  controller: _tabController,
                                  isScrollable: true,
                                  tabAlignment: TabAlignment.start,
                                  dividerColor: Colors.transparent,
                                  indicatorColor: LoginColors.accentPurple,
                                  labelColor: isDark ? Colors.white : theme.colorScheme.primary,
                                  unselectedLabelColor: isDark 
                                      ? Colors.white.withValues(alpha: 0.6) 
                                      : theme.colorScheme.onSurfaceVariant,
                                  tabs: [
                                    const Tab(text: '最近播放'), // Localized in real app preferably
                                    Tab(text: l10n.get('favorites')),
                                    ...playlists.map((p) => Tab(text: p.name)),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add),
                                tooltip: '新建歌单',
                                onPressed: () => _showCreatePlaylistDialog(context),
                              ),
                              const SizedBox(width: 8),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ];
                },
                body: TabBarView(
                  controller: _tabController,
                  children: [
                    const RecentlyPlayedView(),
                    const FavoritesView(),
                    ...playlists.map((p) => PlaylistView(playlistId: p.id)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, s) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }

  Widget _buildLogo(bool isDark, ThemeData theme) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                LoginColors.accentPurple,
                LoginColors.accentPink,
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: LoginColors.accentPurple.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.music_note_rounded,
            color: Colors.white,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'Follow Music',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildUserAvatar(user, bool isDark, ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: LoginColors.accentPurple.withValues(alpha: 0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: LoginColors.accentPurple.withValues(alpha: 0.2),
            blurRadius: 8,
          ),
        ],
      ),
      child: CircleAvatar(
        radius: 18,
        backgroundColor: isDark
            ? LoginColors.cardBackground
            : theme.colorScheme.primaryContainer,
        child: Text(
          user.username[0].toUpperCase(),
          style: TextStyle(
            color: isDark
                ? Colors.white
                : theme.colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Future<void> _showCreatePlaylistDialog(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新建歌单'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '请输入歌单名称',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await ref.read(playlistsProvider.notifier).create(controller.text);
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }
}

class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _StickyTabBarDelegate({required this.child});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  double get maxExtent => 48.0;

  @override
  double get minExtent => 48.0;

  @override
  bool shouldRebuild(_StickyTabBarDelegate oldDelegate) {
    return true; // Rebuild to handle dynamic tabs
  }
}

