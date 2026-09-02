import 'package:flutter/material.dart';
import 'package:follow/core/theme/follow_theme_tokens.dart';
import 'package:follow/core/utils/duration_utils.dart';

/// A reusable progress bar for audio playback.
/// Shows current position, duration, and supports seeking via drag.
class PlayerProgressBar extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;
  final bool showTimeLabels;
  final double height;
  final double thumbRadius;
  final EdgeInsets padding;

  const PlayerProgressBar({
    super.key,
    required this.position,
    required this.duration,
    required this.onSeek,
    this.showTimeLabels = true,
    this.height = 6,
    this.thumbRadius = 8,
    this.padding = const EdgeInsets.symmetric(horizontal: 32),
  });

  @override
  State<PlayerProgressBar> createState() => _PlayerProgressBarState();
}

class _PlayerProgressBarState extends State<PlayerProgressBar> {
  bool _isDragging = false;
  double _dragProgress = 0.0;

  double get _progress {
    if (_isDragging) return _dragProgress;
    if (widget.duration.inMilliseconds <= 0) return 0.0;
    return (widget.position.inMilliseconds / widget.duration.inMilliseconds)
        .clamp(0.0, 1.0);
  }

  Duration get _displayPosition {
    if (_isDragging) {
      return Duration(
        milliseconds: (widget.duration.inMilliseconds * _dragProgress).toInt(),
      );
    }
    return widget.position;
  }

  Color _foregroundColor({double alpha = 1.0}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.white : Colors.black87;
    return alpha < 1.0 ? baseColor.withValues(alpha: alpha) : baseColor;
  }

  Color _trackColor() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? Colors.white.withValues(alpha: 0.2)
        : Colors.black.withValues(alpha: 0.15);
  }

  void _handleDragStart(DragStartDetails details, double trackWidth) {
    setState(() {
      _isDragging = true;
      _dragProgress = (details.localPosition.dx / trackWidth).clamp(0.0, 1.0);
    });
  }

  void _handleDragUpdate(DragUpdateDetails details, double trackWidth) {
    setState(() {
      _dragProgress = (details.localPosition.dx / trackWidth).clamp(0.0, 1.0);
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    final seekPosition = Duration(
      milliseconds: (widget.duration.inMilliseconds * _dragProgress).toInt(),
    );
    widget.onSeek(seekPosition);
    setState(() {
      _isDragging = false;
    });
  }

  void _handleTap(TapUpDetails details, double trackWidth) {
    final tapProgress = (details.localPosition.dx / trackWidth).clamp(0.0, 1.0);
    final seekPosition = Duration(
      milliseconds: (widget.duration.inMilliseconds * tapProgress).toInt(),
    );
    widget.onSeek(seekPosition);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: widget.padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final trackWidth = constraints.maxWidth;
              return GestureDetector(
                onHorizontalDragStart: (details) =>
                    _handleDragStart(details, trackWidth),
                onHorizontalDragUpdate: (details) =>
                    _handleDragUpdate(details, trackWidth),
                onHorizontalDragEnd: _handleDragEnd,
                onTapUp: (details) => _handleTap(details, trackWidth),
                child: Container(
                  height: widget.height + widget.thumbRadius * 2,
                  color: Colors.transparent,
                  child: Center(
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.centerLeft,
                      children: [
                        // Background track
                        Container(
                          height: widget.height,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: _trackColor(),
                            borderRadius: BorderRadius.circular(
                              widget.height / 2,
                            ),
                          ),
                        ),
                        // Progress fill (left to right)
                        FractionallySizedBox(
                          widthFactor: _progress,
                          child: Container(
                            height: widget.height,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  context.followTokens.brandPrimary,
                                  context.followTokens.brandSecondary,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(
                                widget.height / 2,
                              ),
                            ),
                          ),
                        ),
                        // Thumb indicator
                        Positioned(
                          left: (_progress * trackWidth) - widget.thumbRadius,
                          child: Container(
                            width: widget.thumbRadius * 2,
                            height: widget.thumbRadius * 2,
                            decoration: BoxDecoration(
                              color: context.followTokens.brandPrimary,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: context.followTokens.brandPrimary
                                      .withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          if (widget.showTimeLabels) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  formatDuration(_displayPosition),
                  style: TextStyle(
                    fontSize: 12,
                    color: _foregroundColor(alpha: 0.6),
                  ),
                ),
                Text(
                  formatDuration(widget.duration),
                  style: TextStyle(
                    fontSize: 12,
                    color: _foregroundColor(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
