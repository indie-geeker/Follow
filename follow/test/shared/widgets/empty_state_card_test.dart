import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow/shared/widgets/empty_state_card.dart';

void main() {
  testWidgets('empty state action is accessible and invokes its callback', (
    tester,
  ) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmptyStateCard(
            icon: Icons.history_rounded,
            title: '暂无播放记录',
            subtitle: '从音乐库挑一首喜欢的歌开始播放',
            actionLabel: '进入音乐库',
            actionIcon: Icons.library_music_rounded,
            onAction: () => tapped = true,
          ),
        ),
      ),
    );

    final action = find.widgetWithText(FilledButton, '进入音乐库');
    expect(action, findsOneWidget);
    expect(tester.getSize(action).height, greaterThanOrEqualTo(48));

    await tester.tap(action);
    expect(tapped, isTrue);
  });

  testWidgets('empty state omits the action when no callback is supplied', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EmptyStateCard(
            icon: Icons.history_rounded,
            title: '暂无播放记录',
            subtitle: '从音乐库挑一首喜欢的歌开始播放',
          ),
        ),
      ),
    );

    expect(find.byType(FilledButton), findsNothing);
  });
}
