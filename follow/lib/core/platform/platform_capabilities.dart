import 'package:flutter/foundation.dart';

/// Whether [platform] has a native implementation for browsing directories.
bool supportsNativeFolderBrowsing(TargetPlatform platform) {
  return switch (platform) {
    TargetPlatform.macOS ||
    TargetPlatform.windows ||
    TargetPlatform.linux => true,
    TargetPlatform.android ||
    TargetPlatform.iOS ||
    TargetPlatform.fuchsia => false,
  };
}

/// Authenticated playback must keep every hop on HTTPS. `just_audio`'s header
/// proxy is a cleartext localhost hop, so supported platforms send the bearer
/// header through their native media implementation instead.
bool shouldUseAudioProxyForRequestHeaders(TargetPlatform _) => false;
