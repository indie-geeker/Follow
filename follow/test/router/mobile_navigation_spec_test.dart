import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow/features/home/home_page.dart';
import 'package:follow/router/mobile_navigation.dart';

void main() {
  test('mobile primary navigation contains four non-search destinations', () {
    expect(mobileNavigationDestinations, const [
      MobileNavigationDestination.home,
      MobileNavigationDestination.library,
      MobileNavigationDestination.downloads,
      MobileNavigationDestination.settings,
    ]);
    expect(mobileNavigationDestinations, hasLength(4));
  });

  test('mobile and desktop layouts share the 800dp breakpoint', () {
    expect(usesDesktopNavigation(799), isFalse);
    expect(usesDesktopNavigation(800), isTrue);
    expect(shouldOpenPlayerAfterTrackSelection(799), isTrue);
    expect(shouldOpenPlayerAfterTrackSelection(800), isFalse);
  });

  test('desktop shell keeps the dynamic player palette out of app chrome', () {
    final router = File('lib/router/app_router.dart').readAsStringSync();
    final desktopShell = router.substring(
      router.indexOf('class _DesktopShell'),
      router.indexOf('// ============ Detail Pages'),
    );

    expect(desktopShell, contains('DesktopPlayerBar('));
    expect(desktopShell, contains('LyricsOverlay('));
    expect(desktopShell, isNot(contains('PlayerAuroraBackground(')));
    expect(desktopShell, isNot(contains('playerPaletteProvider(')));
    expect(desktopShell, isNot(contains('Theme(')));
  });

  test('all single-track entry points use mobile player navigation', () {
    final sources = [
      'lib/shared/widgets/smart_track_tile.dart',
      'lib/features/search/search_page.dart',
      'lib/features/library/widgets/library_search_box.dart',
      'lib/features/downloads/downloads_page.dart',
    ].map((path) => File(path).readAsStringSync());

    for (final source in sources) {
      expect(source, contains('playTrackAndOpenPlayer('));
    }
  });

  test('search is a guarded secondary route, not a primary tab', () {
    final router = File('lib/router/app_router.dart').readAsStringSync();
    final mobileShell = router.substring(
      router.indexOf('class _MobileShell'),
      router.indexOf('// ============ Desktop Layout'),
    );
    final desktopShell = router.substring(
      router.indexOf('class _DesktopShell'),
      router.indexOf('// ============ Detail Pages'),
    );

    expect(
      router,
      contains(
        RegExp(
          r"AutoRoute\(\s*page: SearchRoute\.page,\s*path: '/search',\s*guards: \[AuthGuard\(\)\],?\s*\)",
        ),
      ),
    );
    expect(mobileShell, isNot(contains('SearchRoute()')));
    expect(desktopShell, isNot(contains('SearchRoute()')));
  });

  testWidgets('home atmosphere reaches behind the top safe-area inset', (
    tester,
  ) async {
    const viewportKey = Key('home-scroll-viewport');

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(padding: EdgeInsets.only(top: 32)),
          child: Scaffold(
            body: HomeScrollSafeArea(
              child: ListView(
                key: viewportKey,
                children: const [SizedBox(height: 1200)],
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.getTopLeft(find.byKey(viewportKey)).dy, 0);
    await tester.drag(find.byKey(viewportKey), const Offset(0, -300));
    await tester.pump();
    expect(tester.getTopLeft(find.byKey(viewportKey)).dy, 0);
  });

  test('recently played injects a semantic library navigation action', () {
    final home = File('lib/features/home/home_page.dart').readAsStringSync();
    final recent = File(
      'lib/features/home/views/recently_played_view.dart',
    ).readAsStringSync();

    expect(recent, contains('required this.onBrowseLibrary'));
    expect(recent, contains("actionLabel: '进入音乐库'"));
    expect(
      home,
      contains(
        RegExp(
          r'AutoTabsRouter\.of\(\s*context\s*,?\s*\)\.navigate\(\s*const LibraryRoute\(\)\s*\)',
        ),
      ),
    );
  });

  test('library launches an autofocus search route on compact layouts', () {
    final library = File(
      'lib/features/library/library_page.dart',
    ).readAsStringSync();
    final search = File(
      'lib/features/search/search_page.dart',
    ).readAsStringSync();

    expect(library, contains('usesDesktopNavigation'));
    expect(library, contains('dimension: 48'));
    expect(
      library,
      contains(
        RegExp(r'context\.router\.root\.push\(\s*const SearchRoute\(\)\s*\)'),
      ),
    );
    expect(search, contains('autofocus: true'));
    expect(search, contains('context.router.maybePop()'));
  });
}
