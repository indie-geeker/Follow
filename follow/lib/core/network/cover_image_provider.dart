import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';
import 'package:follow/core/network/media_url.dart';
import 'package:follow/data/models/track.dart';

ImageProvider<Object>? coverImageProviderForTrack(Track? track) {
  return coverImageProviderForUrl(track?.coverUrl);
}

ImageProvider<Object>? coverImageProviderForUrl(String? coverUrl) {
  return coverImageProviderForUri(resolveCoverUri(coverUrl));
}

ImageProvider<Object>? coverImageProviderForUri(Uri? coverUri) {
  if (coverUri == null) return null;
  return CachedNetworkImageProvider(coverUri.toString());
}

String? coverImageIdentityForTrack(Track? track) {
  return resolveCoverUri(track?.coverUrl)?.toString();
}
