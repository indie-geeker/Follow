import 'package:flutter_test/flutter_test.dart';
import 'package:follow/data/providers/audio_provider.dart';

void main() {
  group('resolveAdjacentQueueIndex', () {
    test('wraps forward and backward in sequence mode', () {
      expect(
        resolveAdjacentQueueIndex(
          queueLength: 3,
          currentIndex: 2,
          mode: PlayMode.sequence,
          shuffledIndices: const [],
          delta: 1,
        ),
        0,
      );
      expect(
        resolveAdjacentQueueIndex(
          queueLength: 3,
          currentIndex: 0,
          mode: PlayMode.sequence,
          shuffledIndices: const [],
          delta: -1,
        ),
        2,
      );
    });

    test('follows the generated shuffle order in both directions', () {
      expect(
        resolveAdjacentQueueIndex(
          queueLength: 3,
          currentIndex: 0,
          mode: PlayMode.shuffle,
          shuffledIndices: const [2, 0, 1],
          delta: 1,
        ),
        1,
      );
      expect(
        resolveAdjacentQueueIndex(
          queueLength: 3,
          currentIndex: 0,
          mode: PlayMode.shuffle,
          shuffledIndices: const [2, 0, 1],
          delta: -1,
        ),
        2,
      );
    });

    test('keeps the current item in single mode', () {
      expect(
        resolveAdjacentQueueIndex(
          queueLength: 3,
          currentIndex: 1,
          mode: PlayMode.single,
          shuffledIndices: const [],
          delta: 1,
        ),
        1,
      );
    });

    test('returns null when no adjacent queue order is available', () {
      expect(
        resolveAdjacentQueueIndex(
          queueLength: 0,
          currentIndex: 0,
          mode: PlayMode.sequence,
          shuffledIndices: const [],
          delta: 1,
        ),
        isNull,
      );
      expect(
        resolveAdjacentQueueIndex(
          queueLength: 3,
          currentIndex: 0,
          mode: PlayMode.shuffle,
          shuffledIndices: const [],
          delta: 1,
        ),
        isNull,
      );
    });
  });
}
