import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:follow/data/providers/lyrics_provider.dart';

class LyricsFailureView extends ConsumerWidget {
  final Color? foregroundColor;

  const LyricsFailureView({super.key, this.foregroundColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = foregroundColor ?? Theme.of(context).colorScheme.onSurface;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('歌词加载失败，请重试', style: TextStyle(fontSize: 16, color: color)),
          const SizedBox(height: 12),
          Tooltip(
            message: '重新加载歌词',
            child: OutlinedButton.icon(
              onPressed: () => ref.invalidate(currentTrackLyricsProvider),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('重试'),
            ),
          ),
        ],
      ),
    );
  }
}
