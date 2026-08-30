import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('track library requests the next page near the list boundary', () {
    final source = File(
      'lib/features/library/library_page.dart',
    ).readAsStringSync();

    expect(source, contains('NotificationListener<ScrollNotification>'));
    expect(source, contains('metrics.extentAfter'));
    expect(source, contains('.loadMore()'));
    expect(source, contains('.hasMore'));
  });
}
