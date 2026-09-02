import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow/features/home/home_page.dart';

const _scrollKey = ValueKey('home-collapse-scroll');
const _tabKey = ValueKey('home-collapse-tabs');
const _heroKey = ValueKey('home-collapse-hero');

Widget _harness() {
  return MaterialApp(
    home: MediaQuery(
      data: const MediaQueryData(
        size: Size(390, 844),
        padding: EdgeInsets.only(top: 32),
        viewPadding: EdgeInsets.only(top: 32),
      ),
      child: Scaffold(
        body: HomeScrollSafeArea(
          child: CustomScrollView(
            key: _scrollKey,
            physics: const HomeHeaderSnapScrollPhysics(collapseRange: 132),
            slivers: [
              HomeCollapsingHeader(
                expandedHeight: 180,
                heroBuilder: (progress) => ColoredBox(
                  key: _heroKey,
                  color: Color.lerp(
                    Colors.purple,
                    Colors.transparent,
                    progress,
                  )!,
                ),
                tabs: const SizedBox(
                  key: _tabKey,
                  height: 48,
                  child: Text('最近播放'),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 1400)),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> _slowDrag(WidgetTester tester, Offset offset) async {
  final gesture = await tester.startGesture(
    tester.getCenter(find.byKey(_scrollKey)),
  );
  await gesture.moveBy(offset);
  await tester.pump(const Duration(milliseconds: 450));
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('tabs pin below the status bar after the hero fully collapses', (
    tester,
  ) async {
    await tester.pumpWidget(_harness());

    await _slowDrag(tester, const Offset(0, -260));

    expect(tester.getTopLeft(find.byKey(_tabKey)).dy, closeTo(32, 0.5));
    expect(tester.getSize(find.byKey(homeHeaderFlexibleSpaceKey)).height, 80);
  });

  testWidgets('a short collapse drag snaps the hero open', (tester) async {
    await tester.pumpWidget(_harness());

    await _slowDrag(tester, const Offset(0, -40));

    expect(
      tester.getSize(find.byKey(homeHeaderFlexibleSpaceKey)).height,
      closeTo(212, 0.5),
    );
  });

  testWidgets('a drag beyond the snap midpoint completes collapse', (
    tester,
  ) async {
    await tester.pumpWidget(_harness());

    await _slowDrag(tester, const Offset(0, -100));

    expect(tester.getSize(find.byKey(homeHeaderFlexibleSpaceKey)).height, 80);
  });

  testWidgets('collapsed tabs use translucent separation, not an opaque seam', (
    tester,
  ) async {
    await tester.pumpWidget(_harness());
    await _slowDrag(tester, const Offset(0, -260));

    final surface = tester.widget<DecoratedBox>(
      find.byKey(homePinnedTabSurfaceKey),
    );
    final decoration = surface.decoration as BoxDecoration;
    expect(decoration.color?.a, lessThan(1));
    expect(decoration.border?.bottom.width, 0.5);
  });

  testWidgets('home scroll scene reaches the top system edge', (tester) async {
    await tester.pumpWidget(_harness());

    expect(tester.getTopLeft(find.byKey(_scrollKey)).dy, 0);
    final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first,
    );
    expect(region.value.statusBarColor, Colors.transparent);
  });
}
