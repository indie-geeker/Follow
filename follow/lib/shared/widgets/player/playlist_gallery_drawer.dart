import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:follow/core/network/media_url.dart';
import 'package:follow/core/theme/follow_theme_tokens.dart';
import 'package:follow/core/theme/player_palette.dart';
import 'package:follow/data/models/track.dart';
import 'package:follow/shared/widgets/loading/app_content_skeleton.dart';
import 'package:follow/shared/widgets/states/app_state_kind.dart';
import 'package:follow/shared/widgets/states/app_state_view.dart';
import 'package:follow/shared/widgets/states/state_illustration_color_mapper.dart';

const playlistGalleryPageViewKey = ValueKey('playlist-gallery-page-view');
const playlistGalleryBusyKey = ValueKey('playlist-gallery-busy');
const playlistGallerySurfaceKey = ValueKey('playlist-gallery-surface');
const playlistGalleryEmptyReadingPanelKey = ValueKey(
  'playlist-gallery-empty-reading-panel',
);
const playlistGalleryEmptyTitleKey = ValueKey('playlist-gallery-empty-title');
const playlistGalleryEmptyDescriptionKey = ValueKey(
  'playlist-gallery-empty-description',
);

Key playlistCardScaleKey(String playlistId) {
  return ValueKey('playlist-card-scale-$playlistId');
}

Key playlistCardStackKey(String playlistId) {
  return ValueKey('playlist-card-stack-$playlistId');
}

Key playlistCenteredCardKey(String playlistId) {
  return ValueKey('playlist-centered-card-$playlistId');
}

class PlaylistGalleryDrawer extends StatefulWidget {
  const PlaylistGalleryDrawer({
    super.key,
    required this.playlists,
    required this.currentPlaylistId,
    required this.onSelect,
    required this.onClose,
    this.onRetry,
    this.palette,
  });

  final AsyncValue<List<Playlist>> playlists;
  final String? currentPlaylistId;
  final Future<void> Function(Playlist playlist) onSelect;
  final VoidCallback onClose;
  final VoidCallback? onRetry;
  final PlayerPalette? palette;

  @override
  State<PlaylistGalleryDrawer> createState() => _PlaylistGalleryDrawerState();
}

class _PlaylistGalleryDrawerState extends State<PlaylistGalleryDrawer> {
  late final PageController _controller;
  late int _focusedIndex;
  bool _isSelecting = false;
  Offset? _pointerDownPosition;
  bool _pointerStartedOnControl = false;

  List<Playlist> get _playlists => widget.playlists.asData?.value ?? const [];

  @override
  void initState() {
    super.initState();
    _focusedIndex = _initialIndex(_playlists);
    _controller = PageController(
      initialPage: _focusedIndex,
      viewportFraction: 0.58,
    );
  }

  @override
  void didUpdateWidget(covariant PlaylistGalleryDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldPlaylists =
        oldWidget.playlists.asData?.value ?? const <Playlist>[];
    if (oldPlaylists.isEmpty && _playlists.isNotEmpty) {
      final index = _initialIndex(_playlists);
      _focusedIndex = index;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.hasClients) {
          _controller.jumpToPage(index);
        }
      });
    }
  }

  int _initialIndex(List<Playlist> playlists) {
    final index = playlists.indexWhere(
      (playlist) => playlist.id == widget.currentPlaylistId,
    );
    return index < 0 ? 0 : index;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _select(Playlist playlist) async {
    if (_isSelecting) return;
    setState(() => _isSelecting = true);
    try {
      await widget.onSelect(playlist);
    } finally {
      if (mounted) setState(() => _isSelecting = false);
    }
  }

  void _moveFocus(int delta) {
    if (_playlists.isEmpty) return;
    final target = (_focusedIndex + delta).clamp(0, _playlists.length - 1);
    if (target == _focusedIndex) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpToPage(target);
    } else {
      _controller.animateToPage(
        target,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _markInteractivePointer() {
    _pointerStartedOnControl = true;
  }

  void _finishPointer(Offset position) {
    final start = _pointerDownPosition;
    final shouldDismiss =
        !_pointerStartedOnControl &&
        start != null &&
        (position - start).distance < 8;
    _pointerDownPosition = null;
    _pointerStartedOnControl = false;
    if (shouldDismiss) widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.followTokens;
    final palette =
        widget.palette ??
        PlayerPalette.fallback(
          brightness: theme.brightness,
          tokens: context.followTokens,
        );
    final surfaceGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color.alphaBlend(
          palette.secondary.withValues(alpha: 0.04),
          tokens.surface,
        ),
        Color.alphaBlend(
          palette.ambient.withValues(alpha: 0.06),
          tokens.surface,
        ),
        Color.alphaBlend(
          palette.secondary.withValues(alpha: 0.1),
          Color.alphaBlend(
            palette.ambient.withValues(alpha: 0.1),
            tokens.surface,
          ),
        ),
      ],
      stops: const [0, 0.68, 1],
    );
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) => _pointerDownPosition = event.position,
      onPointerUp: (event) => _finishPointer(event.position),
      onPointerCancel: (_) {
        _pointerDownPosition = null;
        _pointerStartedOnControl = false;
      },
      child: Material(
        type: MaterialType.transparency,
        child: DecoratedBox(
          key: playlistGallerySurfaceKey,
          decoration: BoxDecoration(gradient: surfaceGradient),
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '选择歌单',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: tokens.textPrimary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Theme(
                    data: theme.copyWith(
                      textTheme: theme.textTheme.copyWith(
                        titleLarge: theme.textTheme.titleLarge?.copyWith(
                          color: tokens.textPrimary,
                        ),
                        bodyMedium: theme.textTheme.bodyMedium?.copyWith(
                          color: tokens.textSecondary,
                        ),
                      ),
                    ),
                    child: _buildBody(context, palette),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, PlayerPalette palette) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return widget.playlists.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: AppContentSkeleton(itemCount: 3, itemHeight: 96),
      ),
      error: (_, __) => AppStateView(
        kind: AppStateKind.failure,
        title: '歌单加载失败',
        description: '暂时无法读取歌单，请稍后重试。',
        actionLabel: widget.onRetry == null ? null : '重试',
        onAction: widget.onRetry,
      ),
      data: (playlists) {
        if (playlists.isEmpty) {
          return _buildEmptyContent(context, palette);
        }

        return Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      radius: 0.72,
                      colors: [
                        Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.04),
                        palette.secondary.withValues(alpha: 0.18),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            PageView.builder(
              key: playlistGalleryPageViewKey,
              controller: _controller,
              itemCount: playlists.length,
              onPageChanged: (index) => setState(() => _focusedIndex = index),
              itemBuilder: (context, index) {
                return AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    final page =
                        _controller.hasClients &&
                            _controller.position.haveDimensions
                        ? _controller.page ?? _focusedIndex.toDouble()
                        : _focusedIndex.toDouble();
                    final signedDistance = index - page;
                    final distance = signedDistance.abs();
                    final scale = reduceMotion
                        ? 1.0
                        : 1.0 - math.min<double>(distance * 0.16, 0.16);
                    final opacity = reduceMotion
                        ? 1.0
                        : 1.0 - math.min<double>(distance * 0.28, 0.34);
                    final stackOffset = reduceMotion
                        ? 0.0
                        : signedDistance.clamp(-1.0, 1.0) * -100;
                    return Transform.translate(
                      key: playlistCardStackKey(playlists[index].id),
                      offset: Offset(stackOffset, 0),
                      child: Transform.scale(
                        key: playlistCardScaleKey(playlists[index].id),
                        scale: scale,
                        child: Opacity(opacity: opacity, child: child),
                      ),
                    );
                  },
                  child: _PlaylistRecordCard(
                    key: index == _focusedIndex
                        ? playlistCenteredCardKey(playlists[index].id)
                        : ValueKey('playlist-card-${playlists[index].id}'),
                    playlist: playlists[index],
                    isCurrent: playlists[index].id == widget.currentPlaylistId,
                    showPlayButton: index == _focusedIndex,
                    onPlay: () => _select(playlists[index]),
                    onControlPointerDown: _markInteractivePointer,
                    onTap: () {
                      if (index != _focusedIndex) {
                        if (reduceMotion) {
                          _controller.jumpToPage(index);
                        } else {
                          _controller.animateToPage(
                            index,
                            duration: const Duration(milliseconds: 240),
                            curve: Curves.easeOutCubic,
                          );
                        }
                      }
                    },
                    palette: palette,
                  ),
                );
              },
            ),
            Positioned(
              left: 8,
              child: Listener(
                onPointerDown: (_) => _markInteractivePointer(),
                child: _GalleryArrowButton(
                  tooltip: '上一个歌单',
                  icon: Icons.chevron_left_rounded,
                  enabled: _focusedIndex > 0,
                  onPressed: () => _moveFocus(-1),
                ),
              ),
            ),
            Positioned(
              right: 8,
              child: Listener(
                onPointerDown: (_) => _markInteractivePointer(),
                child: _GalleryArrowButton(
                  tooltip: '下一个歌单',
                  icon: Icons.chevron_right_rounded,
                  enabled: _focusedIndex < playlists.length - 1,
                  onPressed: () => _moveFocus(1),
                ),
              ),
            ),
            if (_isSelecting)
              Positioned.fill(
                child: ColoredBox(
                  key: playlistGalleryBusyKey,
                  color: Colors.black.withValues(alpha: 0.2),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyContent(BuildContext context, PlayerPalette palette) {
    final tokens = context.followTokens;
    final panelColor = Color.alphaBlend(
      palette.secondary.withValues(alpha: 0.06),
      tokens.surfaceElevated,
    );
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              'assets/illustrations/state_empty_playlist.svg',
              width: 104,
              height: 104,
              fit: BoxFit.contain,
              semanticsLabel: '两张等待连接的唱片插画',
              colorMapper: StateIllustrationColorMapper(tokens),
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: DecoratedBox(
                key: playlistGalleryEmptyReadingPanelKey,
                decoration: BoxDecoration(
                  color: panelColor,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '暂无歌单',
                        key: playlistGalleryEmptyTitleKey,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: tokens.textPrimary,
                          fontSize: 18,
                          height: 1.35,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '创建歌单后，可以在这里快速切换播放来源。',
                        key: playlistGalleryEmptyDescriptionKey,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: tokens.textPrimary.withValues(alpha: 0.78),
                          fontSize: 14,
                          height: 1.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaylistRecordCard extends StatelessWidget {
  const _PlaylistRecordCard({
    super.key,
    required this.playlist,
    required this.isCurrent,
    required this.showPlayButton,
    required this.onPlay,
    required this.onControlPointerDown,
    required this.onTap,
    required this.palette,
  });

  final Playlist playlist;
  final bool isCurrent;
  final bool showPlayButton;
  final VoidCallback onPlay;
  final VoidCallback onControlPointerDown;
  final VoidCallback onTap;
  final PlayerPalette palette;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semanticLabel = [
      '歌单：${playlist.name}',
      '${playlist.trackCount} 首',
      if (isCurrent) '当前播放歌单',
    ].join('，');

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.square(
                dimension: 144,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.32),
                        blurRadius: 22,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: ClipOval(child: _buildArtwork(context)),
                ),
              ),
              if (showPlayButton)
                Listener(
                  onPointerDown: (_) => onControlPointerDown(),
                  child: Tooltip(
                    message: '播放歌单 ${playlist.name}',
                    child: Material(
                      color: theme.colorScheme.surface.withValues(alpha: 0.88),
                      shape: const CircleBorder(),
                      elevation: 8,
                      child: InkWell(
                        onTap: onPlay,
                        customBorder: const CircleBorder(),
                        child: SizedBox.square(
                          dimension: 56,
                          child: Icon(
                            Icons.play_arrow_rounded,
                            size: 34,
                            color: palette.secondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            playlist.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text('${playlist.trackCount} 首', style: theme.textTheme.bodySmall),
        ],
      ),
    );

    return Semantics(
      button: !showPlayButton,
      selected: isCurrent,
      label: semanticLabel,
      child: showPlayButton
          ? content
          : InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(20),
              child: content,
            ),
    );
  }

  Widget _buildArtwork(BuildContext context) {
    final coverUri = resolveCoverUri(playlist.coverUrl);
    if (coverUri != null) {
      return CachedNetworkImage(
        imageUrl: coverUri.toString(),
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => _placeholder(context),
        placeholder: (_, __) => _placeholder(context),
      );
    }
    return _placeholder(context);
  }

  Widget _placeholder(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.primaryContainer, colors.secondaryContainer],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Icon(Icons.album_rounded, size: 72),
          Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _GalleryArrowButton extends StatelessWidget {
  const _GalleryArrowButton({
    required this.tooltip,
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return IconButton.filledTonal(
      tooltip: tooltip,
      onPressed: enabled ? onPressed : null,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        minimumSize: const Size.square(48),
        backgroundColor: colors.surface.withValues(alpha: 0.82),
      ),
    );
  }
}
