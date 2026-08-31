import 'package:flutter_test/flutter_test.dart';
import 'package:follow/shared/widgets/lyrics/lyrics_scroll_geometry.dart';

void main() {
  test('returns the visible row nearest to the viewport center', () {
    const rows = [
      VisibleLyricGeometry(index: 0, center: 20),
      VisibleLyricGeometry(index: 1, center: 48),
      VisibleLyricGeometry(index: 2, center: 90),
    ];

    final result = findNearestLyricIndex(
      rows: rows,
      viewportCenter: 50,
      scrollDirection: 0,
    );

    expect(result, 1);
  });

  test('breaks equal-distance ties using the scroll direction', () {
    const rows = [
      VisibleLyricGeometry(index: 3, center: 40),
      VisibleLyricGeometry(index: 7, center: 60),
    ];

    expect(
      findNearestLyricIndex(rows: rows, viewportCenter: 50, scrollDirection: 1),
      7,
    );
    expect(
      findNearestLyricIndex(
        rows: rows,
        viewportCenter: 50,
        scrollDirection: -1,
      ),
      3,
    );
    expect(
      findNearestLyricIndex(rows: rows, viewportCenter: 50, scrollDirection: 0),
      3,
    );
  });

  test('returns null when there are no visible rows', () {
    expect(
      findNearestLyricIndex(
        rows: const [],
        viewportCenter: 50,
        scrollDirection: 0,
      ),
      isNull,
    );
  });
}
