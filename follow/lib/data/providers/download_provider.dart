import 'dart:io';
import 'package:background_downloader/background_downloader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:follow/data/models/track.dart';
import 'package:follow/core/config/app_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'download_provider.g.dart';

/// Download task state
class DownloadTaskInfo {
  final String trackId;
  final String trackTitle;
  final double progress;
  final TaskStatus status;
  final String? localPath;

  DownloadTaskInfo({
    required this.trackId,
    required this.trackTitle,
    this.progress = 0,
    this.status = TaskStatus.enqueued,
    this.localPath,
  });

  DownloadTaskInfo copyWith({
    double? progress,
    TaskStatus? status,
    String? localPath,
  }) {
    return DownloadTaskInfo(
      trackId: trackId,
      trackTitle: trackTitle,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      localPath: localPath ?? this.localPath,
    );
  }
}

/// Download manager
@riverpod
class DownloadManager extends _$DownloadManager {
  final Map<String, DownloadTask> _tasks = {};

  @override
  Map<String, DownloadTaskInfo> build() {
    _initDownloader();
    return {};
  }

  void _initDownloader() {
    FileDownloader().registerCallbacks(
      taskProgressCallback: _onProgress,
      taskStatusCallback: _onStatus,
    );
  }

  void _onProgress(TaskUpdate update) {
    if (update is TaskProgressUpdate) {
      final taskId = update.task.taskId;
      if (state.containsKey(taskId)) {
        state = {
          ...state,
          taskId: state[taskId]!.copyWith(progress: update.progress),
        };
      }
    }
  }

  void _onStatus(TaskUpdate update) async {
    if (update is TaskStatusUpdate) {
      final taskId = update.task.taskId;
      if (state.containsKey(taskId)) {
        String? localPath;
        if (update.status == TaskStatus.complete) {
          localPath = await update.task.filePath();
        }
        state = {
          ...state,
          taskId: state[taskId]!.copyWith(
            status: update.status,
            localPath: localPath,
          ),
        };
      }
    }
  }

  Future<void> downloadTrack(Track track) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    
    final dir = await getApplicationDocumentsDirectory();
    final downloadDir = Directory('${dir.path}/music');
    if (!await downloadDir.exists()) {
      await downloadDir.create(recursive: true);
    }

    final fileName = '${track.id}.mp3';
    final url = '${AppConfig.apiBaseUrl}/api/tracks/${track.id}/stream';

    final task = DownloadTask(
      taskId: track.id,
      url: url,
      filename: fileName,
      directory: downloadDir.path,
      headers: token != null ? {'Authorization': 'Bearer $token'} : {},
      updates: Updates.statusAndProgress,
    );

    _tasks[track.id] = task;
    state = {
      ...state,
      track.id: DownloadTaskInfo(
        trackId: track.id,
        trackTitle: track.title,
        status: TaskStatus.enqueued,
      ),
    };

    await FileDownloader().enqueue(task);
  }

  Future<void> cancelDownload(String trackId) async {
    if (_tasks.containsKey(trackId)) {
      await FileDownloader().cancelTaskWithId(trackId);
      _tasks.remove(trackId);
      state = Map.from(state)..remove(trackId);
    }
  }

  Future<void> pauseDownload(String trackId) async {
    if (_tasks.containsKey(trackId)) {
      await FileDownloader().pause(_tasks[trackId]!);
    }
  }

  Future<void> resumeDownload(String trackId) async {
    if (_tasks.containsKey(trackId)) {
      await FileDownloader().resume(_tasks[trackId]!);
    }
  }
}

/// Downloaded tracks list
@riverpod
class DownloadedTracks extends _$DownloadedTracks {
  @override
  Future<List<Track>> build() async {
    return await _loadDownloadedTracks();
  }

  Future<List<Track>> _loadDownloadedTracks() async {
    final dir = await getApplicationDocumentsDirectory();
    final downloadDir = Directory('${dir.path}/music');
    
    if (!await downloadDir.exists()) {
      return [];
    }

    // In a real app, you'd store track metadata in a local database
    // For now, just return empty list
    return [];
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = AsyncValue.data(await _loadDownloadedTracks());
  }
}

/// Check if track is downloaded
@riverpod
Future<bool> isTrackDownloaded(ref, String trackId) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/music/$trackId.mp3');
  return file.exists();
}
