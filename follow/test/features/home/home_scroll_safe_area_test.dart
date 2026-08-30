import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow/features/home/home_page.dart';

void main() {
  testWidgets('home scroll viewport stays below the top system inset', (
    tester,
  ) async {
    const contentKey = Key('scroll-content');

    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(padding: EdgeInsets.only(top: 36, bottom: 24)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox.expand(
            child: HomeScrollSafeArea(
              child: SizedBox(key: contentKey, width: 100, height: 100),
            ),
          ),
        ),
      ),
    );

    expect(tester.getTopLeft(find.byKey(contentKey)).dy, 36);
    expect(
      tester.getBottomRight(find.byKey(contentKey)).dy,
      tester.view.physicalSize.height / tester.view.devicePixelRatio,
    );
  });
}
