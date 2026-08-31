import 'package:flutter/foundation.dart';

@immutable
class VisibleLyricGeometry {
  const VisibleLyricGeometry({required this.index, required this.center});

  final int index;
  final double center;
}

int? findNearestLyricIndex({
  required Iterable<VisibleLyricGeometry> rows,
  required double viewportCenter,
  required int scrollDirection,
}) {
  VisibleLyricGeometry? nearestRow;
  double? nearestDistance;

  for (final row in rows) {
    final distance = (row.center - viewportCenter).abs();
    final isCloser = nearestDistance == null || distance < nearestDistance;
    final isPreferredTie =
        distance == nearestDistance &&
        ((scrollDirection > 0 && row.index > nearestRow!.index) ||
            (scrollDirection <= 0 && row.index < nearestRow!.index));

    if (isCloser || isPreferredTie) {
      nearestRow = row;
      nearestDistance = distance;
    }
  }

  return nearestRow?.index;
}
