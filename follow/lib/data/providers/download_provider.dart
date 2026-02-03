import 'dart:convert';
import 'dart:io';
import 'package:background_downloader/background_downloader.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_dir/open_dir.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:follow/data/models/track.dart';
import 'package:follow/core/config/app_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'download_provider.g.dart';

const _downloadPathKey = 'custom_download_path';

/// Download task state
class DownloadTaskInfo {
  final String trackId;
  final String trackTitle;
  final String? artistId;
  final String? artistName;
  final String? coverUrl;
  final double progress;
  final TaskStatus status;
  final String? localPath;

  DownloadTaskInfo({
    required this.trackId,
    required this.trackTitle,
    this.artistId,
    this.artistName,
    this.coverUrl,
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
      artistId: artistId,
      artistName: artistName,
      coverUrl: coverUrl,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      localPath: localPath ?? this.localPath,
    );
  }
}

/// Download manager
@Riverpod(keepAlive: true)
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
      print('Download Progress: ${update.task.taskId} - ${update.progress}');
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
      // Debug log
      print('Download Status: ${update.task.taskId} - ${update.status}'); 
      final taskId = update.task.taskId;
      if (update.exception != null) {
        print('Download Exception for $taskId: ${update.exception}');
      }
      if (state.containsKey(taskId)) {
        String? localPath;
        if (update.status == TaskStatus.complete) {
          localPath = await update.task.filePath();
          print('Download Complete: $localPath');
          // Save track metadata for persistence
          final taskInfo = state[taskId]!;
          await _saveTrackMetadata(taskId, taskInfo, localPath!);
          // Refresh downloaded tracks list
          ref.invalidate(downloadedTracksProvider);
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

  /// Save track metadata to SharedPreferences for persistence
  Future<void> _saveTrackMetadata(String trackId, DownloadTaskInfo taskInfo, String localPath) async {
    final prefs = await SharedPreferences.getInstance();
    final metadataKey = 'downloaded_tracks_metadata';
    final existingData = prefs.getString(metadataKey);
    
    Map<String, dynamic> allMetadata = {};
    if (existingData != null) {
      allMetadata = Map<String, dynamic>.from(jsonDecode(existingData));
    }
    
    allMetadata[trackId] = {
      'title': taskInfo.trackTitle,
      'artistId': taskInfo.artistId,
      'artistName': taskInfo.artistName,
      'coverUrl': taskInfo.coverUrl,
      'localPath': localPath,
      'downloadedAt': DateTime.now().toIso8601String(),
    };
    
    await prefs.setString(metadataKey, jsonEncode(allMetadata));
    print('Saved metadata for track: $trackId - ${taskInfo.trackTitle} by ${taskInfo.artistName}');
  }

  Future<void> downloadTrack(Track track) async {
    print('Starting download for track: ${track.id} - ${track.title}');
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    
    // Get custom or default download path
    final downloadPath = await ref.read(downloadPathProvider.future);
    final downloadDir = Directory(downloadPath);
    if (!await downloadDir.exists()) {
      await downloadDir.create(recursive: true);
    }
    print('Download directory: ${downloadDir.path}');

    final fileName = '${track.id}.mp3';
    final url = '${AppConfig.apiBaseUrl}/api/tracks/${track.id}/stream';
    print('Download URL: $url');

    final task = DownloadTask(
      taskId: track.id,
      url: url,
      filename: fileName,
      directory: downloadPath, // Use custom or default path
      baseDirectory: BaseDirectory.root,
      headers: token != null ? {'Authorization': 'Bearer $token'} : {},
      updates: Updates.statusAndProgress,
      retries: 3,
      allowPause: true,
      metaData: track.title, // Store title in metadata for easy retrieval
    );

    _tasks[track.id] = task;
    // Update state immediately
    state = {
      ...state,
      track.id: DownloadTaskInfo(
        trackId: track.id,
        trackTitle: track.title,
        artistId: track.artist?.id,
        artistName: track.artist?.name,
        coverUrl: track.coverUrl,
        status: TaskStatus.enqueued,
      ),
    };
    print('Task enqueued in state');

    final result = await FileDownloader().enqueue(task);
    print('Enqueue result: $result');
  }

  Future<void> cancelDownload(String trackId) async {
    print('Cancelling download: $trackId');
    if (_tasks.containsKey(trackId)) {
      await FileDownloader().cancelTaskWithId(trackId);
      _tasks.remove(trackId);
      state = Map.from(state)..remove(trackId);
    }
  }

  Future<void> pauseDownload(String trackId) async {
    print('Pausing download: $trackId');
    if (_tasks.containsKey(trackId)) {
      await FileDownloader().pause(_tasks[trackId]!);
    }
  }

  Future<void> resumeDownload(String trackId) async {
    print('Resuming download: $trackId');
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
    // Get custom or default download path
    final prefs = await SharedPreferences.getInstance();
    final customPath = prefs.getString(_downloadPathKey);
    String downloadPath;
    if (customPath != null && await Directory(customPath).exists()) {
      downloadPath = customPath;
    } else {
      final dir = await getApplicationDocumentsDirectory();
      downloadPath = '${dir.path}/music';
    }
    
    final downloadDir = Directory(downloadPath);
    
    if (!await downloadDir.exists()) {
      return [];
    }

    // Load saved metadata from SharedPreferences
    final metadataKey = 'downloaded_tracks_metadata';
    final existingData = prefs.getString(metadataKey);
    
    Map<String, dynamic> allMetadata = {};
    if (existingData != null) {
      allMetadata = Map<String, dynamic>.from(jsonDecode(existingData));
    }
    
    // Scan directory
    try {
      if (await downloadDir.exists()) {
        final files = downloadDir.listSync().whereType<File>().where((f) => f.path.endsWith('.mp3'));
        
        final tracks = <Track>[];
        for (final file in files) {
           final filename = file.path.split(Platform.pathSeparator).last;
           final id = filename.replaceAll('.mp3', '');
           
           // Get saved metadata or use fallback
           final metadata = allMetadata[id] as Map<String, dynamic>?;
           final title = metadata?['title'] as String? ?? 'Unknown Song';
           final artistId = metadata?['artistId'] as String? ?? 'unknown';
           final artistName = metadata?['artistName'] as String? ?? 'Unknown Artist';
           final coverUrl = metadata?['coverUrl'] as String?;
           
           tracks.add(Track(
               id: id, 
               title: title,
               artist: Artist(id: artistId, name: artistName),
               coverUrl: coverUrl,
               durationSeconds: 0,
               createdAt: DateTime.now(),
               isDownloaded: true,
               localPath: file.path,
             ));
        }
        return tracks;
      }
    } catch (e) {
      print('Error loading downloaded tracks: $e');
    }
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
  final downloadPath = await ref.watch(downloadPathProvider.future);
  final file = File('$downloadPath/$trackId.mp3');
  return file.exists();
}

/// Download path provider - manages custom download location
@Riverpod(keepAlive: true)
class DownloadPath extends _$DownloadPath {
  @override
  Future<String> build() async {
    final prefs = await SharedPreferences.getInstance();
    final customPath = prefs.getString(_downloadPathKey);
    if (customPath != null && await Directory(customPath).exists()) {
      return customPath;
    }
    // Default path
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/music';
  }

  /// Pick a new download folder
  Future<String?> pickDownloadFolder() async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '选择下载文件夹',
    );
    if (result != null) {
      await setDownloadPath(result);
      return result;
    }
    return null;
  }

  /// Set custom download path
  Future<void> setDownloadPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_downloadPathKey, path);
    state = AsyncValue.data(path);
    // Refresh downloaded tracks list
    ref.invalidate(downloadedTracksProvider);
  }

  /// Reset to default path
  Future<void> resetToDefault() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_downloadPathKey);
    final dir = await getApplicationDocumentsDirectory();
    final defaultPath = '${dir.path}/music';
    state = AsyncValue.data(defaultPath);
    ref.invalidate(downloadedTracksProvider);
  }

  /// Open download folder in Finder
  Future<void> openDownloadFolder() async {
    final path = state.value;
    if (path != null) {
      await OpenDir().openNativeDir(path: path);
    }
  }

  /// Reveal a specific file in Finder
  Future<void> revealFileInFinder(String trackId) async {
    final path = state.value;
    if (path != null) {
      final filePath = '$path/$trackId.mp3';
      final file = File(filePath);
      if (await file.exists()) {
        // Open the directory and highlight the file
        await OpenDir().openNativeDir(path: path, highlightedFileName: '$trackId.mp3');
      }
    }
  }
}
