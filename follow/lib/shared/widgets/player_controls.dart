import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:follow/data/providers/audio_provider.dart';
import 'package:follow/shared/widgets/play_queue_sheet.dart';
import 'package:follow/data/models/track.dart';

class LikeButton extends ConsumerWidget {
  final Track track;
  final double size;

  const LikeButton({
    required this.track,
    this.size = 24.0,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavoriteAsync = ref.watch(isFavoriteProvider(track.id));
    
    return IconButton(
      icon: isFavoriteAsync.when(
        data: (isFav) => Icon(
          isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          color: isFav ? Colors.red : null,
          size: size,
        ),
        loading: () => SizedBox(
          width: size * 0.6, 
          height: size * 0.6, 
          child: const CircularProgressIndicator(strokeWidth: 2),
        ),
        error: (_, __) => Icon(Icons.favorite_border_rounded, size: size),
      ),
      onPressed: () {
        ref.read(isFavoriteProvider(track.id).notifier).toggle();
      },
    );
  }
}

class PlayPauseButton extends ConsumerWidget {
  final bool isPlaying;
  final double size;
  final Color? color;
  final Color? backgroundColor;

  const PlayPauseButton({
    required this.isPlaying,
    this.size = 32.0,
    this.color,
    this.backgroundColor,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioService = ref.watch(audioPlayerServiceProvider);
    
    final icon = Icon(
      isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
      size: size,
      color: color,
    );

    if (backgroundColor != null) {
      return Container(
         width: size * 1.5,
         height: size * 1.5,
         decoration: BoxDecoration(
           color: backgroundColor,
           shape: BoxShape.circle,
         ),
         child: Material(
           color: Colors.transparent,
           child: InkWell(
             onTap: () {
               if (isPlaying) {
                 audioService.pause();
               } else {
                 audioService.play();
               }
             },
             customBorder: const CircleBorder(),
             child: Center(
               child: icon,
             ),
           ),
         ),
      );
    }

    return IconButton(
      icon: icon,
      onPressed: () {
        if (isPlaying) {
          audioService.pause();
        } else {
          audioService.play();
        }
      },
    );
  }
}

class PlayModeButton extends ConsumerWidget {
  final double size;

  const PlayModeButton({
    this.size = 24.0,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(playerModeProvider);
    
    IconData icon;
    switch (mode) {
      case PlayMode.sequence:
        icon = Icons.repeat_rounded;
        break;
      case PlayMode.shuffle:
        icon = Icons.shuffle_rounded;
        break;
      case PlayMode.single:
        icon = Icons.repeat_one_rounded;
        break;
    }

    return IconButton(
      icon: Icon(icon, size: size),
      onPressed: () {
        ref.read(playerModeProvider.notifier).nextMode();
      },
    );
  }
}

class PlaylistButton extends ConsumerWidget {
  final double size;

  const PlaylistButton({
    this.size = 24.0,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: Icon(Icons.format_list_bulleted_rounded, size: size),
      onPressed: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => const PlayQueueSheet(),
        );
      },
    );
  }
}
