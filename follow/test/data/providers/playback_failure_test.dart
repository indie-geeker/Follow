import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow/data/providers/audio_provider.dart';

void main() {
  test('playback failures expose a safe recovery message', () {
    const secretBearingError =
        'HTTP 401 at http://10.0.2.2/audio?token=super-secret';

    final message = playbackFailureMessage(Exception(secretBearingError));

    expect(message, '无法播放此歌曲，请检查网络后重试');
    expect(message, isNot(contains('super-secret')));
    expect(message, isNot(contains('10.0.2.2')));
  });

  test('playback failure provider can report and clear one-shot feedback', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(playbackFailureProvider), isNull);

    container
        .read(playbackFailureProvider.notifier)
        .report(Exception('decoder failed'));
    expect(container.read(playbackFailureProvider), '无法播放此歌曲，请检查网络后重试');

    container.read(playbackFailureProvider.notifier).clear();
    expect(container.read(playbackFailureProvider), isNull);
  });
}
