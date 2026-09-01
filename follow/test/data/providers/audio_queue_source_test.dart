import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow/data/models/track.dart';
import 'package:follow/data/providers/audio_provider.dart';

const _tracks = [
  Track(id: 'track-1', title: 'Track 1'),
  Track(id: 'track-2', title: 'Track 2'),
  Track(id: 'track-3', title: 'Track 3'),
];

class _RecordingAudioPlayerService extends AudioPlayerService {
  _RecordingAudioPlayerService(this.testRef) : super(testRef);

  final Ref testRef;

  final playedTracks = <Track>[];

  @override
  Future<void> playTrack(Track track) async {
    playedTracks.add(track);
    testRef.read(currentTrackProvider.notifier).setTrack(track);
  }
}

final _recordingServiceProvider = Provider<_RecordingAudioPlayerService>(
  (ref) => _RecordingAudioPlayerService(ref),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late _RecordingAudioPlayerService service;

  setUp(() {
    container = ProviderContainer();
    service = container.read(_recordingServiceProvider);
  });

  tearDown(() {
    service.dispose();
    container.dispose();
  });

  test('playAll replaces the queue and clears playlist source', () async {
    container
        .read(currentPlaylistIdProvider.notifier)
        .setPlaylistId('playlist-old');

    await service.playAll(_tracks, startIndex: 1);

    expect(container.read(playQueueProvider), _tracks);
    expect(container.read(currentIndexProvider), 1);
    expect(container.read(currentPlaylistIdProvider), isNull);
    expect(service.playedTracks, [_tracks[1]]);
  });

  test('playPlaylist records source and starts at the first track', () async {
    await service.playPlaylist('playlist-1', _tracks);

    expect(container.read(playQueueProvider), _tracks);
    expect(container.read(currentIndexProvider), 0);
    expect(container.read(currentPlaylistIdProvider), 'playlist-1');
    expect(service.playedTracks, [_tracks.first]);
  });

  test('playPlaylist can start at a selected playlist index', () async {
    await service.playPlaylist('playlist-1', _tracks, startIndex: 2);

    expect(container.read(currentIndexProvider), 2);
    expect(container.read(currentPlaylistIdProvider), 'playlist-1');
    expect(service.playedTracks, [_tracks[2]]);
  });

  test('playQueueItemAt preserves playlist source', () async {
    await service.playPlaylist('playlist-1', _tracks);

    await service.playQueueItemAt(2);

    expect(container.read(currentIndexProvider), 2);
    expect(container.read(currentPlaylistIdProvider), 'playlist-1');
    expect(service.playedTracks.last, _tracks[2]);
  });

  test('structural queue mutations clear playlist source', () async {
    await service.playPlaylist('playlist-1', _tracks);

    await service.removeQueueItemAt(2);

    expect(container.read(currentPlaylistIdProvider), isNull);

    await service.playPlaylist('playlist-1', _tracks);
    await service.clearQueue();

    expect(container.read(currentPlaylistIdProvider), isNull);
  });
}
