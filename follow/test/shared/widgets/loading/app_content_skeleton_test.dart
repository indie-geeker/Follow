import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow/core/theme/app_theme.dart';
import 'package:follow/shared/widgets/loading/app_content_skeleton.dart';
import 'package:shimmer/shimmer.dart';

void main() {
  testWidgets('reserves final geometry without showing a state illustration', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: AppContentSkeleton(
            key: Key('skeleton'),
            itemCount: 3,
            itemHeight: 64,
          ),
        ),
      ),
    );

    expect(find.byType(SvgPicture), findsNothing);
    expect(find.byType(Shimmer), findsOneWidget);
    expect(tester.getSize(find.byKey(const Key('skeleton'))).height, 216);
  });

  testWidgets('disables shimmer under reduced motion', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(
          body: AppContentSkeleton(itemCount: 2, reduceMotion: true),
        ),
      ),
    );

    expect(find.byType(Shimmer), findsNothing);
    expect(find.byKey(const Key('skeleton-content')), findsOneWidget);
  });
}
