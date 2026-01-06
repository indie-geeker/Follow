import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:background_downloader/background_downloader.dart';
import 'package:follow/core/l10n/l10n.dart';
import 'package:follow/core/theme/app_theme.dart';
import 'package:follow/data/providers/download_provider.dart';
import 'package:follow/shared/widgets/track_tile.dart';

@RoutePage()
class DownloadsPage extends ConsumerWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final downloadTasks = ref.watch(downloadManagerProvider);
    final downloadedTracksAsync = ref.watch(downloadedTracksProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
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
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    child: Row(
                      children: [
                        Text(
                          l10n.downloads,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : theme.colorScheme.onSurface,
                          ),
                        ),
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
                      labelPadding: EdgeInsets.zero,
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      indicator: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [LoginColors.accentPurple, LoginColors.accentPink],
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
                      tabs: [
                        Tab(text: l10n.get('downloading')),
                        Tab(text: l10n.get('downloaded')),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Tab content
                  Expanded(
                    child: TabBarView(
                      children: [
                        _DownloadingTab(tasks: downloadTasks, isDark: isDark),
                        _DownloadedTab(tracksAsync: downloadedTracksAsync, isDark: isDark),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DownloadingTab extends ConsumerWidget {
  final Map<String, DownloadTaskInfo> tasks;
  final bool isDark;

  const _DownloadingTab({required this.tasks, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final activeTasks = tasks.values.where(
      (t) => t.status != TaskStatus.complete && t.status != TaskStatus.failed,
    ).toList();

    if (activeTasks.isEmpty) {
      return _buildEmptyState(
        icon: Icons.download_outlined,
        title: '暂无下载任务',
        subtitle: '在音乐库中选择歌曲下载',
        isDark: isDark,
        theme: theme,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: activeTasks.length,
      itemBuilder: (context, index) {
        final task = activeTasks[index];
        return _DownloadingItem(task: task, isDark: isDark);
      },
    );
  }
}

class _DownloadingItem extends ConsumerWidget {
  final DownloadTaskInfo task;
  final bool isDark;

  const _DownloadingItem({required this.task, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? LoginColors.cardBackground
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: isDark ? Border.all(color: LoginColors.cardBorder) : null,
      ),
      child: Row(
        children: [
          // Progress indicator
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  value: task.progress,
                  strokeWidth: 3,
                  backgroundColor: isDark
                      ? LoginColors.inputBackground
                      : theme.colorScheme.surfaceContainerHighest,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    LoginColors.accentPurple,
                  ),
                ),
              ),
              Text(
                '${(task.progress * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),

          const SizedBox(width: 16),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.trackTitle,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : theme.colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _getStatusText(task.status),
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? LoginColors.textSecondary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          // Actions
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (task.status == TaskStatus.running)
                _buildActionButton(
                  icon: Icons.pause_rounded,
                  onPressed: () {
                    ref.read(downloadManagerProvider.notifier).pauseDownload(task.trackId);
                  },
                  isDark: isDark,
                ),
              if (task.status == TaskStatus.paused)
                _buildActionButton(
                  icon: Icons.play_arrow_rounded,
                  onPressed: () {
                    ref.read(downloadManagerProvider.notifier).resumeDownload(task.trackId);
                  },
                  isDark: isDark,
                ),
              const SizedBox(width: 8),
              _buildActionButton(
                icon: Icons.close_rounded,
                onPressed: () {
                  ref.read(downloadManagerProvider.notifier).cancelDownload(task.trackId);
                },
                isDark: isDark,
                isDestructive: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onPressed,
    required bool isDark,
    bool isDestructive = false,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDestructive
              ? Colors.red.withValues(alpha: 0.15)
              : (isDark
                  ? LoginColors.accentPurple.withValues(alpha: 0.2)
                  : LoginColors.accentPurple.withValues(alpha: 0.1)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 20,
          color: isDestructive
              ? Colors.red
              : LoginColors.accentPurple,
        ),
      ),
    );
  }

  String _getStatusText(TaskStatus status) {
    switch (status) {
      case TaskStatus.enqueued:
        return '等待中';
      case TaskStatus.running:
        return '下载中';
      case TaskStatus.paused:
        return '已暂停';
      case TaskStatus.complete:
        return '已完成';
      case TaskStatus.failed:
        return '下载失败';
      default:
        return '';
    }
  }
}

class _DownloadedTab extends StatelessWidget {
  final AsyncValue<List<dynamic>> tracksAsync;
  final bool isDark;

  const _DownloadedTab({required this.tracksAsync, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return tracksAsync.when(
      data: (tracks) {
        if (tracks.isEmpty) {
          return _buildEmptyState(
            icon: Icons.download_done_outlined,
            title: '暂无已下载音乐',
            subtitle: '在音乐库中长按歌曲选择下载',
            isDark: isDark,
            theme: theme,
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 100),
          itemCount: tracks.length,
          itemBuilder: (context, index) {
            final track = tracks[index];
            return TrackTile(
              track: track,
              onTap: () {},
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
              '加载失败',
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _buildEmptyState({
  required IconData icon,
  required String title,
  required String subtitle,
  required bool isDark,
  required ThemeData theme,
}) {
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
            color: isDark ? LoginColors.accentPurple : theme.colorScheme.primary,
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
