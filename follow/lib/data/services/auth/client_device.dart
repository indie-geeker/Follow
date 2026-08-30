import 'package:flutter/foundation.dart';

String clientDeviceName({
  TargetPlatform? platform,
  bool? isWeb,
}) {
  platform ??= defaultTargetPlatform;
  isWeb ??= kIsWeb;
  if (isWeb) return 'Follow Web';
  return switch (platform) {
    TargetPlatform.android => 'Follow Android',
    TargetPlatform.iOS => 'Follow iOS',
    TargetPlatform.macOS => 'Follow Mac',
    TargetPlatform.windows => 'Follow Windows',
    TargetPlatform.linux => 'Follow Linux',
    TargetPlatform.fuchsia => 'Follow Fuchsia',
  };
}
