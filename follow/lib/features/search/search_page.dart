import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:follow/core/l10n/l10n.dart';
import 'package:follow/core/theme/app_theme.dart';
import 'package:follow/data/providers/track_provider.dart';
import 'package:follow/data/providers/audio_provider.dart';
import 'package:follow/shared/widgets/track_tile.dart';
import 'package:follow/shared/widgets/empty_state.dart';
import 'package:follow/features/search/providers/search_provider.dart';

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
                // Header with search bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.search,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Glassmorphism search bar
                      Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? LoginColors.cardBackground
                              : theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(16),
                          border: isDark
                              ? Border.all(color: LoginColors.cardBorder)
                              : null,
                          boxShadow: isDark
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        child: TextField(
                          controller: _searchController,
                          focusNode: _focusNode,
                          style: TextStyle(
                            color: isDark ? Colors.white : theme.colorScheme.onSurface,
                            fontSize: 16,
                          ),
                          decoration: InputDecoration(
                            hintText: '搜索歌曲、艺术家或专辑...',
                            hintStyle: TextStyle(
                              color: isDark
                                  ? LoginColors.textHint
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                            prefixIcon: Container(
                              padding: const EdgeInsets.all(12),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      LoginColors.accentPurple,
                                      LoginColors.accentPink,
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
                                          ? LoginColors.textSecondary
                                          : theme.colorScheme.onSurfaceVariant,
                                    ),
                                    onPressed: () {
                                      _searchController.clear();
                                      ref.read(searchQueryProvider.notifier).state = '';
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
                             ref.read(searchQueryProvider.notifier).state = value.trim();
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // Results
                Expanded(
                  child: query.isEmpty
                    ? const EmptyState(
                        icon: Icons.search_rounded,
                        title: '搜索音乐',
                        subtitle: '输入关键词搜索歌曲、艺术家或专辑',
                      )
                    : _buildSearchResults(ref, currentTrack, isDark, query),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(WidgetRef ref, currentTrack, bool isDark, String query) {
    final resultsAsync = ref.watch(searchTracksProvider(query));
    final theme = Theme.of(context);

    return resultsAsync.when(
      data: (tracks) {
        if (tracks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: isDark
                        ? LoginColors.cardBackground
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.music_off_rounded,
                    size: 40,
                    color: isDark
                        ? LoginColors.textSecondary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '未找到结果',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '没有找到 "$query" 相关的音乐',
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

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 100),
          itemCount: tracks.length,
          itemBuilder: (context, index) {
            final track = tracks[index];
            return TrackTile(
              track: track,
              isPlaying: currentTrack?.id == track.id,
              onTap: () {
                ref.read(currentTrackProvider.notifier).setTrack(track);
                ref.read(playQueueProvider.notifier).setQueue(tracks);
                ref.read(currentIndexProvider.notifier).setIndex(index);
                ref.read(audioPlayerServiceProvider).playTrack(track);
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              '搜索失败',
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
        ),
      ),
    );
  }
}
