import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:follow/core/theme/app_theme.dart';
import 'package:follow/features/search/providers/search_provider.dart';
import 'package:follow/shared/widgets/track_tile.dart';
import 'package:follow/data/providers/audio_provider.dart';

class LibrarySearchBox extends ConsumerStatefulWidget {
  const LibrarySearchBox({super.key});

  @override
  ConsumerState<LibrarySearchBox> createState() => _LibrarySearchBoxState();
}

class _LibrarySearchBoxState extends ConsumerState<LibrarySearchBox> {
  final TextEditingController _controller = TextEditingController();
  final LayerLink _layerLink = LayerLink();
  final FocusNode _focusNode = FocusNode();
  OverlayEntry? _overlayEntry;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _showOverlay() {
    if (_overlayEntry != null) return;

    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _createOverlayEntry() {
    return OverlayEntry(
      builder: (context) {
        return Positioned(
          width: 300, // Fixed width for the popup
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: const Offset(0, 45), // Position below the search box
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              color: Colors.transparent,
              child: _SearchResultsPopup(
                query: _controller.text,
                onClose: () {
                  _focusNode.unfocus();
                  _removeOverlay();
                },
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return CompositedTransformTarget(
      link: _layerLink,
      child: Container(
        width: 300,
        height: 36,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.transparent,
          ),
        ),
        child: TextField(
          textAlignVertical: TextAlignVertical.center,
          controller: _controller,
          focusNode: _focusNode,
          style: TextStyle(
            color: isDark ? Colors.white : theme.colorScheme.onSurface,
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText: '搜索音乐库...',
            hintStyle: TextStyle(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.5)
                  : theme.colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
            prefixIcon: Icon(
              Icons.search,
              size: 20,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.5)
                  : theme.colorScheme.onSurfaceVariant,
            ),
            suffixIcon: _controller.text.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.clear,
                      size: 16,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.5)
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      _controller.clear();
                      _removeOverlay();
                      setState(() {});
                    },
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 0,
              horizontal: 8,
            ),
            border: InputBorder.none,
            isDense: true,
          ),
          onChanged: (value) {
            setState(() {}); // Rebuild to show/hide suffix icon
            if (value.isNotEmpty) {
              _showOverlay();
              // Iterate logic: ref.read(popupSearchTracksProvider(value)); handled by widget below
              _overlayEntry?.markNeedsBuild();
            } else {
              _removeOverlay();
            }
          },
          onTap: () {
            if (_controller.text.isNotEmpty) {
              _showOverlay();
            }
          },
        ),
      ),
    );
  }
}

class _SearchResultsPopup extends ConsumerWidget {
  final String query;
  final VoidCallback onClose;

  const _SearchResultsPopup({required this.query, required this.onClose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final resultsAsync = ref.watch(popupSearchTracksProvider(query));
    final currentTrack = ref.watch(currentTrackProvider);

    return Container(
      constraints: const BoxConstraints(maxHeight: 400),
      decoration: BoxDecoration(
        color: isDark ? LoginColors.cardBackground : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? LoginColors.cardBorder
              : theme.colorScheme.outlineVariant,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          resultsAsync.when(
            data: (tracks) {
              if (tracks.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    '未找到结果',
                    style: TextStyle(
                      color: isDark
                          ? LoginColors.textSecondary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              }
              return Flexible(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shrinkWrap: true,
                  itemCount: tracks.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.5,
                          ),
                  ),
                  itemBuilder: (context, index) {
                    final track = tracks[index];
                    return TrackTile(
                      track: track,
                      isPlaying: currentTrack?.id == track.id,
                      onTap: () {
                        ref
                            .read(audioPlayerServiceProvider)
                            .playAll(tracks, startIndex: index);
                        onClose();
                      },
                    );
                  },
                ),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (e, s) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '搜索失败',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
