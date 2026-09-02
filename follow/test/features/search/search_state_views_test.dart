import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow/core/l10n/l10n.dart';
import 'package:follow/core/theme/app_theme.dart';
import 'package:follow/data/models/track.dart';
import 'package:follow/data/providers/track_provider.dart';
import 'package:follow/features/search/providers/search_provider.dart';
import 'package:follow/features/search/search_page.dart';
import 'package:follow/shared/widgets/loading/app_content_skeleton.dart';
import 'package:follow/shared/widgets/states/app_state_kind.dart';
import 'package:follow/shared/widgets/states/app_state_view.dart';

void main() {
  testWidgets('no results uses the illustrated state and clears filters', (
    tester,
  ) async {
    final container = await _pumpSearch(
      tester,
      query: 'aurora',
      result: () async => const <Track>[],
    );

    _expectState(AppStateKind.noResults);
    await tester.tap(find.widgetWithText(FilledButton, '清除筛选'));
    await tester.pump();
    expect(container.read(searchQueryProvider), isEmpty);
  });

  testWidgets('search loading uses a geometry skeleton', (tester) async {
    final pending = Completer<List<Track>>();
    await _pumpSearch(tester, query: 'aurora', result: () => pending.future);

    expect(find.byType(AppContentSkeleton), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('search failure retries the same query provider', (tester) async {
    var attempts = 0;
    await _pumpSearch(
      tester,
      query: 'aurora',
      result: () async {
        attempts++;
        throw StateError('offline');
      },
    );
    await tester.pumpAndSettle();

    _expectState(AppStateKind.failure);
    final beforeRetry = attempts;
    await tester.tap(find.widgetWithText(FilledButton, '重试'));
    await tester.pump();
    expect(attempts, greaterThan(beforeRetry));
  });
}

Future<ProviderContainer> _pumpSearch(
  WidgetTester tester, {
  required String query,
  required Future<List<Track>> Function() result,
}) async {
  final container = ProviderContainer(
    overrides: [
      searchQueryProvider.overrideWith((ref) => query),
      searchTracksProvider(query).overrideWith(() => _FakeSearchTracks(result)),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('zh', 'CN'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const SearchPage(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return container;
}

class _FakeSearchTracks extends SearchTracks {
  _FakeSearchTracks(this.loader);

  final Future<List<Track>> Function() loader;

  @override
  Future<List<Track>> build(String query) => loader();
}

void _expectState(AppStateKind kind) {
  final finder = find.byType(AppStateView);
  expect(finder, findsOneWidget);
  expect((finder.evaluate().single.widget as AppStateView).kind, kind);
  expect(find.byIcon(Icons.error_outline), findsNothing);
}
