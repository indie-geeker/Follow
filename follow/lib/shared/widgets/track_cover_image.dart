import 'package:flutter/material.dart';
import 'package:follow/core/network/cover_image_provider.dart';
import 'package:follow/data/models/track.dart';

const trackCoverNetworkImageKey = ValueKey('track-cover-network-image');
const trackCoverPlaceholderKey = ValueKey('track-cover-placeholder');

class TrackCoverImage extends StatelessWidget {
  final Track? track;
  final double size;
  final BorderRadius? borderRadius;
  final BoxFit fit;
  final VoidCallback? onTap;

  const TrackCoverImage({
    super.key,
    required this.track,
    required this.size,
    this.borderRadius,
    this.fit = BoxFit.cover,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget image = _buildImage();

    Widget result = ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(6),
      child: image,
    );

    if (onTap != null) {
      result = GestureDetector(onTap: onTap, child: result);
    }

    return SizedBox.square(dimension: size, child: result);
  }

  Widget _buildImage() {
    final provider = coverImageProviderForTrack(track);
    if (provider != null) {
      return Image(
        key: trackCoverNetworkImageKey,
        image: provider,
        width: size,
        height: size,
        fit: fit,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded || frame != null) return child;
          return _buildPlaceholder();
        },
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
      );
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      key: trackCoverPlaceholderKey,
      width: size,
      height: size,
      color: Colors.grey[300],
      child: Icon(Icons.music_note, size: size * 0.5, color: Colors.grey[500]),
    );
  }
}
