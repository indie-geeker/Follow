import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:follow/core/network/media_url.dart';
import 'package:follow/core/platform/platform_capabilities.dart';
import 'package:follow/data/models/track.dart';
import 'package:follow/data/services/api/api_client.dart';
import 'package:follow/data/services/api/api_service.dart';
import 'package:follow/data/providers/track_provider.dart';
import 'package:follow/data/providers/history_provider.dart';

part 'audio_provider.g.dart';

/// Current playing track state
@Riverpod(keepAlive: true)
class CurrentTrack extends _$CurrentTrack {
  @override
  Track? build() => null;

  void setTrack(Track? track) {
    state = track;
  }
}

/// Play queue
@Riverpod(keepAlive: true)
class PlayQueue extends _$PlayQueue {
  @override
  List<Track> build() => [];

  void setQueue(List<Track> tracks) {
    state = tracks;
  }

  void addToQueue(Track track) {
    state = [...state, track];
  }

  void removeFromQueue(int index) {
    if (index >= 0 && index < state.length) {
      state = [...state]..removeAt(index);
    }
  }

  void clearQueue() {
    state = [];
  }
}

/// Current queue index
@Riverpod(keepAlive: true)
class CurrentIndex extends _$CurrentIndex {
  @override
  int build() => 0;

  void setIndex(int index) {
    state = index;
  }
}

/// Playlist that supplied the current queue, when the queue still matches it.
@Riverpod(keepAlive: true)
class CurrentPlaylistId extends _$CurrentPlaylistId {
  @override
  String? build() => null;

  void setPlaylistId(String? playlistId) {
    state = playlistId;
  }
}

/// Shuffled indices provider — only regenerated explicitly via reshuffle()
@Riverpod(keepAlive: true)
class ShuffledIndices extends _$ShuffledIndices {
  @override
  List<int> build() => [];

  /// Generate a new shuffle order based on current queue length
  void reshuffle(int queueLength) {
    state = List.generate(queueLength, (i) => i)..shuffle();
  }

  /// Remove a queue index and adjust remaining indices to stay valid.
  void removeIndex(int removedIndex) {
    state = state
        .where((i) => i != removedIndex)
        .map((i) => i > removedIndex ? i - 1 : i)
        .toList();
  }
}

String playbackFailureMessage(Object _) {
  return '无法播放此歌曲，请检查网络后重试';
}

Future<T> publishTrackBeforePreparation<T>({
  required Track track,
  required void Function(Track track) publish,
  required Future<T> Function() prepare,
}) {
  publish(track);
  return prepare();
}

/// Starts playback and observes its lifetime Future without waiting for the
/// track to pause, stop, or complete.
Future<void> startPlaybackWithoutWaitingForCompletion({
  required Future<void> Function() play,
  required void Function(Object error, StackTrace stackTrace) onError,
}) async {
  final playback = play();
  unawaited(
    playback.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {
        onError(error, stackTrace);
      },
    ),
  );
}

(double, double) nextMuteVolume({
  required double current,
  required double lastAudible,
}) {
  if (current > 0) return (0.0, current);

  final restored = lastAudible > 0 ? lastAudible : 1.0;
  return (restored, restored);
}

/// Resolves the queue index shown by an adjacent-track gesture.
///
/// Keeping this calculation pure lets the player's preview page use exactly
/// the same sequence and shuffle order as committed playback.
int? resolveAdjacentQueueIndex({
  required int queueLength,
  required int currentIndex,
  required PlayMode mode,
  required List<int> shuffledIndices,
  required int delta,
}) {
  assert(delta == -1 || delta == 1);
  if (queueLength <= 0) return null;
  if (mode == PlayMode.single) return currentIndex;

  if (mode == PlayMode.shuffle) {
    if (shuffledIndices.isEmpty) return null;
    final currentShuffledPosition = shuffledIndices.indexOf(currentIndex);
    if (currentShuffledPosition == -1) return shuffledIndices.first;
    final adjacentPosition =
        (currentShuffledPosition + delta + shuffledIndices.length) %
        shuffledIndices.length;
    return shuffledIndices[adjacentPosition];
  }

  return (currentIndex + delta + queueLength) % queueLength;
}

@Riverpod(keepAlive: true)
class PlaybackFailure extends _$PlaybackFailure {
  @override
  String? build() => null;

  void report(Object error) {
    state = playbackFailureMessage(error);
  }

  void clear() {
    state = null;
  }
}

/// Audio Player Service
class AudioPlayerService {
  final AudioPlayer _player = AudioPlayer(
    useProxyForRequestHeaders: shouldUseAudioProxyForRequestHeaders(
      defaultTargetPlatform,
    ),
  );
  final ApiService _apiService = ApiService();
  final Ref _ref;

  AudioPlayerService(this._ref) {
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _handlePlaybackCompletion();
      }
    });
  }

  AudioPlayer get player => _player;

  Stream<Duration?> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<bool> get playingStream => _player.playingStream;
  Stream<double> get volumeStream => _player.volumeStream;

  bool get isPlaying => _player.playing;
  Duration get position => _player.position;
  Duration? get duration => _player.duration;

  void _reportPlaybackFailure(Object error, StackTrace stackTrace) {
    _ref.read(currentTrackProvider.notifier).setTrack(null);
    _ref.read(playbackFailureProvider.notifier).report(error);
    debugPrint('Playback failed: $error\n$stackTrace');
  }

  Future<void> playTrack(Track track) async {
    _ref.read(playbackFailureProvider.notifier).clear();

    try {
      final tokens = await publishTrackBeforePreparation(
        track: track,
        publish: (selectedTrack) =>
            _ref.read(currentTrackProvider.notifier).setTrack(selectedTrack),
        prepare: ApiClient.tokenStore.readTokens,
      );

      final mediaItem = MediaItem(
        id: track.id,
        title: track.title,
        artist: track.artist?.name,
        album: track.album?.title,
        artUri: resolveCoverUri(track.coverUrl),
        duration: track.durationSeconds > 0
            ? Duration(seconds: track.durationSeconds)
            : null,
      );

      if (track.isDownloaded && track.localPath != null) {
        await _player.setAudioSource(
          AudioSource.file(track.localPath!, tag: mediaItem),
        );
      } else {
        final url = _apiService.getStreamUrl(track.id);
        await _player.setAudioSource(
          AudioSource.uri(
            Uri.parse(url),
            headers: tokens != null
                ? {'Authorization': 'Bearer ${tokens.accessToken}'}
                : null,
            tag: mediaItem,
          ),
        );
      }

      await startPlaybackWithoutWaitingForCompletion(
        play: _player.play,
        onError: _reportPlaybackFailure,
      );

      // Recording history must never block or fail playback.
      _apiService
          .addToHistory(track.id)
          .then((_) => _ref.invalidate(historyProvider))
          .catchError((Object error) {
            debugPrint('Failed to record history: $error');
          });
    } catch (error, stackTrace) {
      _reportPlaybackFailure(error, stackTrace);
    }
  }

  /// Play all tracks in a list starting from the first track
  /// This consolidates the common pattern of setting queue, track, index and playing
  Future<void> playAll(List<Track> tracks, {int startIndex = 0}) async {
    _ref.read(currentPlaylistIdProvider.notifier).setPlaylistId(null);
    await _replaceQueueAndPlay(tracks, startIndex: startIndex);
  }

  /// Replace the queue with a playlist and remember its source.
  Future<void> playPlaylist(
    String playlistId,
    List<Track> tracks, {
    int startIndex = 0,
  }) async {
    if (tracks.isEmpty) return;
    _ref.read(currentPlaylistIdProvider.notifier).setPlaylistId(playlistId);
    await _replaceQueueAndPlay(tracks, startIndex: startIndex);
  }

  Future<void> _replaceQueueAndPlay(
    List<Track> tracks, {
    int startIndex = 0,
  }) async {
    if (tracks.isEmpty) return;
    final index = startIndex.clamp(0, tracks.length - 1);
    _ref.read(playQueueProvider.notifier).setQueue(tracks);
    _ref.read(currentIndexProvider.notifier).setIndex(index);

    // Regenerate shuffle indices for the new queue
    final mode = _ref.read(playerModeProvider);
    if (mode == PlayMode.shuffle) {
      _ref.read(shuffledIndicesProvider.notifier).reshuffle(tracks.length);
    }

    await playTrack(tracks[index]);
  }

  /// Select an item already in the queue without changing its playlist source.
  Future<void> playQueueItemAt(int index) async {
    final queue = _ref.read(playQueueProvider);
    if (index < 0 || index >= queue.length) return;

    _ref.read(currentIndexProvider.notifier).setIndex(index);
    await playTrack(queue[index]);
  }

  Future<void> play() async {
    await _player.play();
  }

  Future<void> pause() async {
    await _player.pause();
  }

  Future<void> stop() async {
    await _player.stop();
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume);
  }

  Future<void> applyPlayMode(PlayMode mode) async {
    await _player.setShuffleModeEnabled(false);
    await _player.setLoopMode(
      mode == PlayMode.single ? LoopMode.one : LoopMode.off,
    );
  }

  Future<void> playNext() async {
    final mode = _ref.read(playerModeProvider);
    final queue = _ref.read(playQueueProvider);
    final currentIndex = _ref.read(currentIndexProvider);

    if (queue.isEmpty) return;

    if (mode == PlayMode.single) {
      // Single loop mode, just replay current
      await seek(Duration.zero);
      await play();
      return;
    }

    final nextIndex = resolveAdjacentQueueIndex(
      queueLength: queue.length,
      currentIndex: currentIndex,
      mode: mode,
      shuffledIndices: _ref.read(shuffledIndicesProvider),
      delta: 1,
    );
    if (nextIndex == null) return;

    _ref.read(currentIndexProvider.notifier).setIndex(nextIndex);
    await playTrack(queue[nextIndex]);
  }

  Future<void> playPrevious() async {
    final mode = _ref.read(playerModeProvider);
    final queue = _ref.read(playQueueProvider);
    final currentIndex = _ref.read(currentIndexProvider);

    if (queue.isEmpty) return;

    if (mode == PlayMode.single) {
      await seek(Duration.zero);
      await play();
      return;
    }

    final prevIndex = resolveAdjacentQueueIndex(
      queueLength: queue.length,
      currentIndex: currentIndex,
      mode: mode,
      shuffledIndices: _ref.read(shuffledIndicesProvider),
      delta: -1,
    );
    if (prevIndex == null) return;

    _ref.read(currentIndexProvider.notifier).setIndex(prevIndex);
    await playTrack(queue[prevIndex]);
  }

  Future<void> removeQueueItemAt(int index) async {
    final queue = _ref.read(playQueueProvider);
    final currentIndex = _ref.read(currentIndexProvider);

    if (index < 0 || index >= queue.length) return;

    _ref.read(currentPlaylistIdProvider.notifier).setPlaylistId(null);

    _ref.read(playQueueProvider.notifier).removeFromQueue(index);

    // Keep shuffle indices consistent after removal
    if (_ref.read(playerModeProvider) == PlayMode.shuffle) {
      _ref.read(shuffledIndicesProvider.notifier).removeIndex(index);
    }

    if (index < currentIndex) {
      // Removing item before current, so current shifts down
      _ref.read(currentIndexProvider.notifier).setIndex(currentIndex - 1);
    } else if (index == currentIndex) {
      // Removing currently playing item
      // Decide logic: Play next?
      // Since queue is already shortened (the item at 'index' is now the NEXT item),
      // we can essentially just "play" the item at the CURRENT index again (which is the new track).
      // But we need to handle if we removed the LAST item.

      // New queue length
      final newQueueLength = queue.length - 1;

      if (newQueueLength == 0) {
        // Queue empty
        await stop();
        _ref.read(currentTrackProvider.notifier).setTrack(null);
        _ref.read(currentIndexProvider.notifier).setIndex(0);
      } else {
        // If we removed the last item, we need to wrap or stop?
        // Let's say we play the previous one or stop?
        // Or if in shuffle, play another.
        // Simple logic: if index == newQueueLength (was last), play 0 (loop) or index-1.

        int newIndex = index;
        if (newIndex >= newQueueLength) {
          newIndex = 0; // Wrap to start or handle end
        }

        _ref.read(currentIndexProvider.notifier).setIndex(newIndex);
        // Play the track at newIndex (which shifted into place)
        // Wait, playQueueProvider was updated. So we need the NEW list.
        final newQueue = _ref.read(playQueueProvider);
        await playTrack(newQueue[newIndex]);
      }
    }
    // If removing after, nothing changes for playback.
  }

  Future<void> clearQueue() async {
    await stop();
    _ref.read(currentPlaylistIdProvider.notifier).setPlaylistId(null);
    _ref.read(playQueueProvider.notifier).clearQueue();
    _ref.read(currentTrackProvider.notifier).setTrack(null);
    _ref.read(currentIndexProvider.notifier).setIndex(0);
  }

  void _handlePlaybackCompletion() {
    playNext();
  }

  void dispose() {
    _player.dispose();
  }
}

/// Audio player service provider - keepAlive to prevent disposal during async operations
@Riverpod(keepAlive: true)
AudioPlayerService audioPlayerService(Ref ref) {
  final service = AudioPlayerService(ref);
  ref.onDispose(() => service.dispose());
  return service;
}

/// Is playing provider
@riverpod
Stream<bool> isPlaying(ref) {
  final service = ref.watch(audioPlayerServiceProvider);
  return service.playingStream;
}

/// Position stream provider
@riverpod
Stream<Duration?> playerPosition(ref) {
  final service = ref.watch(audioPlayerServiceProvider);
  return service.positionStream;
}

/// Duration stream provider
@riverpod
Stream<Duration?> playerDuration(ref) {
  final service = ref.watch(audioPlayerServiceProvider);
  return service.durationStream;
}

/// Volume stream provider
@riverpod
Stream<double> playerVolume(ref) {
  final service = ref.watch(audioPlayerServiceProvider);
  return service.volumeStream;
}

enum PlayMode { sequence, shuffle, single }

@Riverpod(keepAlive: true)
class PlayerMode extends _$PlayerMode {
  @override
  PlayMode build() => PlayMode.sequence;

  Future<void> setMode(PlayMode mode) async {
    state = mode;
    final service = ref.read(audioPlayerServiceProvider);

    await service.applyPlayMode(mode);

    switch (mode) {
      case PlayMode.sequence:
        break;
      case PlayMode.shuffle:
        final queue = ref.read(playQueueProvider);
        ref.read(shuffledIndicesProvider.notifier).reshuffle(queue.length);
        break;
      case PlayMode.single:
        break;
    }
  }

  Future<void> nextMode() async {
    final next = switch (state) {
      PlayMode.sequence => PlayMode.shuffle,
      PlayMode.shuffle => PlayMode.single,
      PlayMode.single => PlayMode.sequence,
    };
    await setMode(next);
  }
}

@riverpod
class IsFavorite extends _$IsFavorite {
  @override
  Future<bool> build(String? trackId) async {
    if (trackId == null) return false;
    final service = ApiService();
    try {
      return await service.checkFavorite(trackId);
    } catch (e) {
      return false;
    }
  }

  Future<void> toggle() async {
    final trackId = this.trackId;
    if (trackId == null) return;

    final service = ApiService();
    final current = state.value ?? false;

    // Optimistic update
    state = AsyncData(!current);

    try {
      if (current) {
        await service.removeFromFavorites(trackId);
      } else {
        await service.addToFavorites(trackId);
      }
      // Refresh the global favorites list so Home Page updates
      ref.invalidate(favoritesProvider);
    } catch (e) {
      // Revert on error
      state = AsyncData(current);
      rethrow;
    }
  }
}
