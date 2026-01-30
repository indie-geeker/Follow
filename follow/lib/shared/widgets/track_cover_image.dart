import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:follow/data/models/track.dart';
import 'package:follow/core/config/app_config.dart';

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

    return result;
  }

  Widget _buildImage() {
    if (track?.coverUrl != null && track!.coverUrl!.isNotEmpty) {
      final url = track!.coverUrl!.startsWith('http')
          ? track!.coverUrl!
          : '${AppConfig.apiBaseUrl}/api/tracks/cover/${Uri.encodeComponent(track!.coverUrl!)}';
      return CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: fit,
        placeholder: (_, __) => _buildPlaceholder(),
        errorWidget: (_, __, ___) => _buildPlaceholder(),
      );
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      width: size,
      height: size,
      color: Colors.grey[300],
      child: Icon(Icons.music_note, size: size * 0.5, color: Colors.grey[500]),
    );
  }
}
