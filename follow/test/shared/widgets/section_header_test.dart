import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow/core/theme/app_theme.dart';
import 'package:follow/shared/widgets/section_header.dart';

void main() {
  testWidgets('uses theme title role and exposes an optional action', (
    tester,
  ) async {
    var pressed = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SectionHeader(
            title: '最近播放',
            actionLabel: '查看全部',
            onAction: () => pressed = true,
          ),
        ),
      ),
    );

    final title = tester.widget<Text>(find.text('最近播放'));
    expect(
      title.style?.fontSize,
      AppTheme.light.textTheme.titleLarge?.fontSize,
    );
    expect(
      title.style?.fontWeight,
      AppTheme.light.textTheme.titleLarge?.fontWeight,
    );

    await tester.tap(find.text('查看全部'));
    expect(pressed, isTrue);
  });

  testWidgets('provides a heading semantic without requiring an action', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(body: SectionHeader(title: '为你推荐')),
      ),
    );

    final semantics = tester.getSemantics(find.text('为你推荐'));
    expect(semantics.flagsCollection.isHeader, isTrue);
  });
}
