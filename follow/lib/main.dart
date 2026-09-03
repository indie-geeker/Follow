import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:follow/app.dart';
import 'package:follow/data/services/auth/remembered_identifier_store.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await migrateLegacyAuthPreferences();

  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.follow.music.channel',
    androidNotificationChannelName: 'Follow Music',
    androidNotificationOngoing: false,
    androidStopForegroundOnPause: true,
  );

  runApp(const ProviderScope(child: FollowApp()));
}
