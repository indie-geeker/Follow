import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow/core/theme/app_theme.dart';
import 'package:follow/shared/widgets/states/app_state_kind.dart';
import 'package:follow/shared/widgets/states/app_state_view.dart';

void main() {
  for (final kind in AppStateKind.values) {
    testWidgets('${kind.name} renders a semantic SVG illustration', (
      tester,
    ) async {
      await tester.pumpWidget(
        _themed(
          AppStateView(kind: kind, title: '状态标题', description: '可恢复的简短说明'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SvgPicture), findsOneWidget);
      expect(find.byIcon(Icons.music_note), findsNothing);
      expect(tester.getSemantics(find.byType(SvgPicture)).label, isNotEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('shows a primary action only when callback and label exist', (
    tester,
  ) async {
    var pressed = false;
    await tester.pumpWidget(
      _themed(
        AppStateView(
          kind: AppStateKind.failure,
          title: '加载失败',
          description: '请稍后重试',
          actionLabel: '重试',
          onAction: () => pressed = true,
        ),
      ),
    );

    await tester.tap(find.widgetWithText(FilledButton, '重试'));
    expect(pressed, isTrue);

    await tester.pumpWidget(
      _themed(
        const AppStateView(
          kind: AppStateKind.failure,
          title: '加载失败',
          description: '请稍后重试',
        ),
      ),
    );
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('uses mobile and desktop illustration sizes', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _themed(
        const AppStateView(
          kind: AppStateKind.emptyLibrary,
          title: '资料库为空',
          description: '添加音乐后会显示在这里',
        ),
      ),
    );
    expect(
      tester.getSize(find.byType(SvgPicture)).width,
      inInclusiveRange(160, 180),
    );

    await tester.binding.setSurfaceSize(const Size(1000, 800));
    await tester.pumpWidget(
      _themed(
        const AppStateView(
          kind: AppStateKind.emptyLibrary,
          title: '资料库为空',
          description: '添加音乐后会显示在这里',
        ),
      ),
    );
    expect(tester.getSize(find.byType(SvgPicture)).width, 220);
  });

  testWidgets('wraps large text without overflow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _themed(
        const AppStateView(
          kind: AppStateKind.noResults,
          title: '没有找到与你当前筛选条件相符的音乐内容',
          description: '尝试清除部分筛选条件，或者换一个更宽泛的关键词继续搜索。',
        ),
        textScaleFactor: 2,
      ),
    );

    expect(tester.takeException(), isNull);
  });
}

Widget _themed(Widget child, {double textScaleFactor = 1}) => MaterialApp(
  theme: AppTheme.light,
  builder: (context, appChild) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScaleFactor)),
    child: appChild!,
  ),
  home: Scaffold(body: Center(child: child)),
);
