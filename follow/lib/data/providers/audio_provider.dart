import 'package:just_audio/just_audio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:follow/data/models/track.dart';
import 'package:follow/data/services/api/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'audio_provider.g.dart';

/// Current playing track state
@riverpod
class CurrentTrack extends _$CurrentTrack {
  @override
  Track? build() => null;

  void setTrack(Track? track) {
    state = track;
  }
}

/// Play queue
@riverpod
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
@riverpod
class CurrentIndex extends _$CurrentIndex {
  @override
  int build() => 0;

  void setIndex(int index) {
    state = index;
  }
}

/// Audio Player Service
class AudioPlayerService {
  final AudioPlayer _player = AudioPlayer();
  final ApiService _apiService = ApiService();
  
  AudioPlayer get player => _player;
  
  Stream<Duration?> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<bool> get playingStream => _player.playingStream;
  
  bool get isPlaying => _player.playing;
  Duration get position => _player.position;
  Duration? get duration => _player.duration;

  Future<void> playTrack(Track track) async {
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

  void dispose() {
    _player.dispose();
  }
}

/// Audio player service provider - keepAlive to prevent disposal during async operations
@Riverpod(keepAlive: true)
AudioPlayerService audioPlayerService(Ref ref) {
  final service = AudioPlayerService();
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
