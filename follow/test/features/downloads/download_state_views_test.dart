import 'dart:async';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow/core/l10n/l10n.dart';
import 'package:follow/core/theme/app_theme.dart';
import 'package:follow/data/models/track.dart';
import 'package:follow/data/providers/download_provider.dart';
import 'package:follow/features/downloads/downloads_page.dart';
import 'package:follow/shared/widgets/loading/app_content_skeleton.dart';
import 'package:follow/shared/widgets/states/app_state_kind.dart';
import 'package:follow/shared/widgets/states/app_state_view.dart';

void main() {
  testWidgets('download tabs use the illustrated empty-downloads state', (
    tester,
  ) async {
    await _pumpDownloads(tester, _FakeDownloadedTracks(() async => const []));
    _expectState(AppStateKind.emptyDownloads);

    await tester.tap(find.text('已下载'));
    await tester.pumpAndSettle();
    _expectState(AppStateKind.emptyDownloads);
  });

  testWidgets('downloaded loading uses a geometry skeleton', (tester) async {
    final pending = Completer<List<Track>>();
    await _pumpDownloads(tester, _FakeDownloadedTracks(() => pending.future));
    await tester.tap(find.text('已下载'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(AppContentSkeleton), findsOneWidget);
  });

  testWidgets('download failure uses a retryable illustrated state', (
    tester,
  ) async {
    final downloaded = _FakeDownloadedTracks(
      () async => throw StateError('disk unavailable'),
    );
    await _pumpDownloads(tester, downloaded);
    await tester.tap(find.text('已下载'));
    await tester.pumpAndSettle();

    _expectState(AppStateKind.failure);
    await tester.tap(find.widgetWithText(FilledButton, '重试'));
    await tester.pump();
    expect(downloaded.refreshCount, 1);
  });

  testWidgets(
    'download progress does not rebuild the complete downloads page',
    (tester) async {
      final manager = _FakeDownloadManager({
        'track-1': DownloadTaskInfo(
          trackId: 'track-1',
          trackTitle: 'Downloading track',
          progress: 0.1,
          status: TaskStatus.running,
        ),
      });
      await _pumpDownloads(
        tester,
        _FakeDownloadedTracks(() async => const []),
        manager: manager,
      );

      final rebuiltTypes = <Type>[];
      final previousRebuildCallback = debugOnRebuildDirtyWidget;
      addTearDown(() => debugOnRebuildDirtyWidget = previousRebuildCallback);
      debugOnRebuildDirtyWidget = (element, _) {
        rebuiltTypes.add(element.widget.runtimeType);
      };

      manager.emit(
        DownloadTaskInfo(
          trackId: 'track-1',
          trackTitle: 'Downloading track',
          progress: 0.2,
          status: TaskStatus.running,
        ),
      );
      await tester.pump();

      expect(rebuiltTypes, isNot(contains(DownloadsPage)));
      expect(find.text('20%'), findsOneWidget);
    },
  );
}

class _FakeDownloadManager extends DownloadManager {
  _FakeDownloadManager([this.initialTasks = const {}]);

  final Map<String, DownloadTaskInfo> initialTasks;

  @override
  Map<String, DownloadTaskInfo> build() => initialTasks;

  void emit(DownloadTaskInfo task) {
    state = {...state, task.trackId: task};
  }
}

class _FakeDownloadedTracks extends DownloadedTracks {
  _FakeDownloadedTracks(this.loader);

  final Future<List<Track>> Function() loader;
  int refreshCount = 0;

  @override
  Future<List<Track>> build() => loader();

  @override
  Future<void> refresh() async {
    refreshCount++;
    state = const AsyncData([]);
  }
}

Future<void> _pumpDownloads(
  WidgetTester tester,
  _FakeDownloadedTracks downloaded, {
  _FakeDownloadManager? manager,
}) async {
  final downloadManager = manager ?? _FakeDownloadManager();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        downloadManagerProvider.overrideWith(() => downloadManager),
        downloadedTracksProvider.overrideWith(() => downloaded),
      ],
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
        home: const DownloadsPage(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void _expectState(AppStateKind kind) {
  final finder = find.byType(AppStateView);
  expect(finder, findsOneWidget);
  expect((finder.evaluate().single.widget as AppStateView).kind, kind);
  expect(find.byIcon(Icons.error_outline), findsNothing);
}
