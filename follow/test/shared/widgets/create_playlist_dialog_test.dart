import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow/core/theme/app_theme.dart';
import 'package:follow/shared/widgets/create_playlist_dialog.dart';

void main() {
  testWidgets('shows a labeled form and disables empty submission', (
    tester,
  ) async {
    await _openDialog(tester, onCreate: (_) async {});

    expect(find.text('新建歌单'), findsOneWidget);
    expect(find.text('为喜欢的音乐留一个专属位置'), findsOneWidget);
    expect(find.text('歌单名称'), findsOneWidget);
    expect(find.text('最多 50 个字符'), findsOneWidget);
    expect(find.byTooltip('关闭'), findsOneWidget);

    final submit = tester.widget<FilledButton>(
      find.byKey(const ValueKey('create-playlist-submit')),
    );
    expect(submit.onPressed, isNull);
  });

  testWidgets('trims the name and shows progress while creating', (
    tester,
  ) async {
    final completion = Completer<void>();
    String? submittedName;
    await _openDialog(
      tester,
      onCreate: (name) {
        submittedName = name;
        return completion.future;
      },
    );

    await tester.enterText(
      find.byKey(const ValueKey('create-playlist-name')),
      '  夜间驾驶  ',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('create-playlist-submit')));
    await tester.pump();

    expect(submittedName, '夜间驾驶');
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final submittingButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('create-playlist-submit')),
    );
    expect(submittingButton.onPressed, isNull);

    completion.complete();
    await tester.pumpAndSettle();

    expect(find.text('新建歌单'), findsNothing);
  });

  testWidgets('keeps the dialog open and explains how to retry on failure', (
    tester,
  ) async {
    await _openDialog(
      tester,
      onCreate: (_) async => throw Exception('offline'),
    );

    await tester.enterText(
      find.byKey(const ValueKey('create-playlist-name')),
      '家庭晚餐',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('create-playlist-submit')));
    await tester.pumpAndSettle();

    expect(find.text('创建失败，请检查网络后重试'), findsOneWidget);
    expect(find.text('新建歌单'), findsOneWidget);
    final submit = tester.widget<FilledButton>(
      find.byKey(const ValueKey('create-playlist-submit')),
    );
    expect(submit.onPressed, isNotNull);
  });
}

Future<void> _openDialog(
  WidgetTester tester, {
  required Future<void> Function(String name) onCreate,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Builder(
          builder: (context) => FilledButton(
            onPressed: () =>
                showCreatePlaylistDialog(context, onCreate: onCreate),
            child: const Text('打开'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('打开'));
  await tester.pumpAndSettle();
}
