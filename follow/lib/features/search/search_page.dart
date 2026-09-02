import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:follow/core/l10n/l10n.dart';
import 'package:follow/core/theme/follow_theme_tokens.dart';
import 'package:follow/data/providers/track_provider.dart';
import 'package:follow/data/providers/audio_provider.dart';
import 'package:follow/shared/widgets/track_tile.dart';
import 'package:follow/features/search/providers/search_provider.dart';
import 'package:follow/router/player_navigation.dart';
import 'package:follow/shared/widgets/loading/app_content_skeleton.dart';
import 'package:follow/shared/widgets/states/app_state_kind.dart';
import 'package:follow/shared/widgets/states/app_state_view.dart';
import 'package:follow/shared/widgets/surfaces/aurora_background.dart';
import 'package:follow/shared/widgets/surfaces/glass_panel.dart';

@RoutePage()
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentTrack = ref.watch(currentTrackProvider);
    final query = ref.watch(searchQueryProvider);

    // Sync controller with provider if needed
    if (_searchController.text != query) {
      _searchController.text = query;
      _searchController.selection = TextSelection.fromPosition(
        TextPosition(offset: _searchController.text.length),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: AuroraBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Header with search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        BackButton(onPressed: () => context.router.maybePop()),
                        const SizedBox(width: 8),
                        Text(
                          l10n.search,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Glassmorphism search bar
                    GlassPanel(
                      tier: GlassTier.standard,
                      borderRadius: BorderRadius.circular(
                        context.followTokens.radiusCard,
                      ),
                      child: TextField(
                        controller: _searchController,
                        focusNode: _focusNode,
                        autofocus: true,
                        style: TextStyle(
                          color: isDark
                              ? Colors.white
                              : theme.colorScheme.onSurface,
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          hintText: '搜索歌曲、艺术家或专辑...',
                          hintStyle: TextStyle(
                            color: isDark
                                ? context.followTokens.textSecondary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                          prefixIcon: Container(
                            padding: const EdgeInsets.all(12),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    context.followTokens.brandPrimary,
                                    context.followTokens.brandSecondary,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.search_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(
                                    Icons.clear_rounded,
                                    color: isDark
                                        ? context.followTokens.textSecondary
                                        : theme.colorScheme.onSurfaceVariant,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    ref
                                            .read(searchQueryProvider.notifier)
                                            .state =
                                        '';
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        onChanged: (value) {
                          // Optional: Debounce here if needed, but strict state sync is simpler for now
                          ref.read(searchQueryProvider.notifier).state = value;
                        },
                        onSubmitted: (value) {
                          ref.read(searchQueryProvider.notifier).state = value
                              .trim();
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // Results
              Expanded(
                child: query.isEmpty
                    ? const AppStateView(
                        kind: AppStateKind.noResults,
                        title: '搜索音乐',
                        description: '输入关键词搜索歌曲、艺术家或专辑',
                      )
                    : _buildSearchResults(ref, currentTrack, query),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults(WidgetRef ref, currentTrack, String query) {
    final resultsAsync = ref.watch(searchTracksProvider(query));
    return resultsAsync.when(
      data: (tracks) {
        if (tracks.isEmpty) {
          return AppStateView(
            kind: AppStateKind.noResults,
            title: '未找到结果',
            description: '没有找到 "$query" 相关的音乐',
            actionLabel: '清除筛选',
            onAction: () {
              _searchController.clear();
              ref.read(searchQueryProvider.notifier).state = '';
            },
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 100),
          itemCount: tracks.length,
          itemBuilder: (context, index) {
            final track = tracks[index];
            return TrackTile(
              track: track,
              isPlaying: currentTrack?.id == track.id,
              onTap: () => playTrackAndOpenPlayer(
                context,
                play: () => ref
                    .read(audioPlayerServiceProvider)
                    .playAll(tracks, startIndex: index),
              ),
            );
          },
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: AppContentSkeleton(itemCount: 5),
      ),
      error: (e, _) => AppStateView(
        kind: AppStateKind.failure,
        title: '搜索失败',
        description: '暂时无法完成搜索，请稍后重试。',
        actionLabel: '重试',
        onAction: () => ref.invalidate(searchTracksProvider(query)),
      ),
    );
  }
}
