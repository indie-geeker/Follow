import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:background_downloader/background_downloader.dart';
import 'package:follow/core/l10n/l10n.dart';
import 'package:follow/data/providers/download_provider.dart';
import 'package:follow/shared/widgets/track_tile.dart';

@RoutePage()
class DownloadsPage extends ConsumerWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final downloadTasks = ref.watch(downloadManagerProvider);
    final downloadedTracksAsync = ref.watch(downloadedTracksProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.downloads),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.get('downloading')),
              Tab(text: l10n.get('downloaded')),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Downloading tab
            _DownloadingTab(tasks: downloadTasks),
            // Downloaded tab
            _DownloadedTab(tracksAsync: downloadedTracksAsync, theme: theme),
          ],
        ),
      ),
    );
  }
}

class _DownloadingTab extends ConsumerWidget {
  final Map<String, DownloadTaskInfo> tasks;

  const _DownloadingTab({required this.tasks});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final activeTasks = tasks.values.where(
      (t) => t.status != TaskStatus.complete && t.status != TaskStatus.failed,
    ).toList();

    if (activeTasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.download_outlined,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              '暂无下载任务',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: activeTasks.length,
      itemBuilder: (context, index) {
        final task = activeTasks[index];
        return _DownloadingItem(task: task);
      },
    );
  }
}

class _DownloadingItem extends ConsumerWidget {
  final DownloadTaskInfo task;

  const _DownloadingItem({required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return ListTile(
      leading: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: task.progress,
            strokeWidth: 3,
          ),
          Text(
            '${(task.progress * 100).toInt()}%',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
      title: Text(task.trackTitle),
      subtitle: Text(_getStatusText(task.status)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (task.status == TaskStatus.running)
            IconButton(
              icon: const Icon(Icons.pause),
              onPressed: () {
                ref.read(downloadManagerProvider.notifier).pauseDownload(task.trackId);
              },
            ),
          if (task.status == TaskStatus.paused)
            IconButton(
              icon: const Icon(Icons.play_arrow),
              onPressed: () {
                ref.read(downloadManagerProvider.notifier).resumeDownload(task.trackId);
              },
            ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              ref.read(downloadManagerProvider.notifier).cancelDownload(task.trackId);
            },
          ),
        ],
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
  final ThemeData theme;

  const _DownloadedTab({required this.tracksAsync, required this.theme});

  @override
  Widget build(BuildContext context) {
    return tracksAsync.when(
      data: (tracks) {
        if (tracks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.download_done_outlined,
                  size: 64,
                  color: theme.colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  '暂无已下载音乐',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '在音乐库中长按歌曲选择下载',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
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
      error: (e, _) => Center(child: Text('加载失败: $e')),
    );
  }
}
