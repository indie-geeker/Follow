import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:follow/router/app_router.dart';
import 'package:follow/router/mobile_navigation.dart';

const playerRouteSlideTransitionKey = ValueKey('player-route-slide-transition');

Widget buildPlayerRouteTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return child;

  final position = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
      .animate(
        CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        ),
      );
  return SlideTransition(
    key: playerRouteSlideTransitionKey,
    position: position,
    child: child,
  );
}

Future<void> coordinateTrackSelection({
  required bool shouldOpenPlayer,
  required Future<void> Function() play,
  required Future<void> Function() openPlayer,
}) async {
  final playback = play();
  if (!shouldOpenPlayer) {
    await playback;
    return;
  }

  unawaited(
    playback.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Deferred track selection failed: $error\n$stackTrace');
      },
    ),
  );
  await openPlayer();
}

/// Starts a single-track selection and opens the full player on compact UI.
///
/// Desktop keeps the persistent player bar workflow. Play-all actions do not
/// use this helper and therefore keep their existing navigation behavior.
Future<void> playTrackAndOpenPlayer(
  BuildContext context, {
  required Future<void> Function() play,
}) async {
  final shouldOpen = shouldOpenPlayerAfterTrackSelection(
    MediaQuery.sizeOf(context).width,
  );
  await coordinateTrackSelection(
    shouldOpenPlayer: shouldOpen,
    play: play,
    openPlayer: () async {
      if (context.mounted) {
        await context.router.push(const PlayerRoute());
      }
    },
  );
}
