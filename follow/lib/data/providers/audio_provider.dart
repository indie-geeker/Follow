import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:follow/data/models/track.dart';
import 'package:follow/data/services/api/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

/// Shuffled indices provider
@Riverpod(keepAlive: true)
class ShuffledIndices extends _$ShuffledIndices {
  @override
  List<int> build() {
    final queue = ref.watch(playQueueProvider);
    return List.generate(queue.length, (i) => i)..shuffle();
  }
}


/// Audio Player Service
class AudioPlayerService {
  final AudioPlayer _player = AudioPlayer();
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

  Future<void> playTrack(Track track) async {
    _ref.read(currentTrackProvider.notifier).setTrack(track);

    // Fire-and-forget: record history without blocking playback
    _apiService.addToHistory(track.id).then((_) {
      _ref.invalidate(historyProvider);
    }).catchError((e) {
      debugPrint('Failed to record history: $e');
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');

    // Check if track is downloaded locally
    if (track.isDownloaded && track.localPath != null) {
      await _player.setFilePath(track.localPath!);
    } else {
      // Stream from server
      final url = _apiService.getStreamUrl(track.id);
      await _player.setUrl(
        url,
        headers: token != null ? {'Authorization': 'Bearer $token'} : null,
      );
    }

    await _player.play();
  }

  /// Play all tracks in a list starting from the first track
  /// This consolidates the common pattern of setting queue, track, index and playing
  Future<void> playAll(List<Track> tracks, {int startIndex = 0}) async {
    if (tracks.isEmpty) return;
    final index = startIndex.clamp(0, tracks.length - 1);
    _ref.read(playQueueProvider.notifier).setQueue(tracks);
    _ref.read(currentTrackProvider.notifier).setTrack(tracks[index]);
    _ref.read(currentIndexProvider.notifier).setIndex(index);
    await playTrack(tracks[index]);
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

    int nextIndex = 0;
    if (mode == PlayMode.shuffle) {
      final shuffledIndices = _ref.read(shuffledIndicesProvider);
      if (shuffledIndices.isEmpty) return; // Should not happen if queue not empty
      
      // Find current index in shuffled list
      // We need to map the actual current index to the position in shuffled list
      // The current index in queue corresponds to some value in shuffledIndices
      
      // Wait, current index points to the PLAYING track in the original queue.
      // So we need to find where this index is in the shuffled list.
      final currentShuffledPos = shuffledIndices.indexOf(currentIndex);
      
      if (currentShuffledPos != -1) {
        final nextShuffledPos = (currentShuffledPos + 1) % shuffledIndices.length;
        nextIndex = shuffledIndices[nextShuffledPos];
      } else {
        // Fallback
         nextIndex = shuffledIndices[0];
      }
    } else {
      // Sequence
      nextIndex = (currentIndex + 1) % queue.length;
    }

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

    int prevIndex = 0;
    if (mode == PlayMode.shuffle) {
      final shuffledIndices = _ref.read(shuffledIndicesProvider);
      if (shuffledIndices.isEmpty) return;
      
      final currentShuffledPos = shuffledIndices.indexOf(currentIndex);
      
      if (currentShuffledPos != -1) {
        // Provide negative wrap-around
        final prevShuffledPos = (currentShuffledPos - 1 + shuffledIndices.length) % shuffledIndices.length;
        prevIndex = shuffledIndices[prevShuffledPos];
      } else {
         prevIndex = shuffledIndices[0];
      }
    } else {
      // Sequence
      prevIndex = (currentIndex - 1 + queue.length) % queue.length;
    }

    _ref.read(currentIndexProvider.notifier).setIndex(prevIndex);
    await playTrack(queue[prevIndex]);
  }

  Future<void> removeQueueItemAt(int index) async {
    final queue = _ref.read(playQueueProvider);
    final currentIndex = _ref.read(currentIndexProvider);
    
    if (index < 0 || index >= queue.length) return;

    // Logic:
    // If removing item BEFORE current: current index decrements
    // If removing item AT current: play next (if avail) or previous or stop.
    // If removing item AFTER current: current index stays same
    
    // We must modify the provider state. 
    // PlayQueue provider has removeFromQueue method.
    _ref.read(playQueueProvider.notifier).removeFromQueue(index);
    // After this, queue length is reduced by 1.

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

enum PlayMode {
  sequence,
  shuffle,
  single,
}

@Riverpod(keepAlive: true)
class PlayerMode extends _$PlayerMode {
  @override
  PlayMode build() => PlayMode.sequence;

  Future<void> setMode(PlayMode mode) async {
    state = mode;
    final service = ref.read(audioPlayerServiceProvider);
    
    switch (mode) {
      case PlayMode.sequence:
        // Shuffle off, Loop off (we handle loop manually)
        await service.player.setShuffleModeEnabled(false);
        await service.player.setLoopMode(LoopMode.off);
        break;
      case PlayMode.shuffle:
        // Shuffle off (we handle shuffle manually), Loop off
        // Note: JustAudio's shuffle is different from our manual shuffle logic implementation detail
        // But to rely on our manual plays, we turn native shuffle off to avoid confusion, 
        // or we keep it off and just use our index logic.
        // Actually, if we use setShuffleModeEnabled(true), JustAudio might change indices internally?
        // No, JustAudio's shuffle just changes the order if we use a ConcatenatingAudioSource.
        // Since we seem to be playing single tracks via setUrl/setFilePath, JustAudio's queue is size 1.
        // So LoopMode.all will just loop this one track.
        // So we MUST use LoopMode.off and handle "next" manually.
        await service.player.setShuffleModeEnabled(false);
        await service.player.setLoopMode(LoopMode.off);
        
        // Force refresh shuffled indices
        ref.invalidate(shuffledIndicesProvider);
        break;
      case PlayMode.single:
        // Loop one
        // Keep shuffle state or disable? usually disable for single loop
        await service.player.setShuffleModeEnabled(false);
        await service.player.setLoopMode(LoopMode.one);
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
