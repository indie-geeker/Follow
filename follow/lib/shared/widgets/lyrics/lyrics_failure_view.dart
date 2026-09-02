import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:follow/data/providers/lyrics_provider.dart';
import 'package:follow/shared/widgets/states/app_state_kind.dart';
import 'package:follow/shared/widgets/states/app_state_view.dart';

class LyricsFailureView extends ConsumerWidget {
  final Color? foregroundColor;

  const LyricsFailureView({super.key, this.foregroundColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppStateView(
      kind: AppStateKind.failure,
      title: '歌词加载失败',
      description: '暂时无法读取歌词，请稍后重试。',
      actionLabel: '重试',
      onAction: () => ref.invalidate(currentTrackLyricsProvider),
      illustrationSize: 132,
    );
  }
}
