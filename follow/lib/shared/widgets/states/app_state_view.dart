import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/follow_theme_tokens.dart';
import 'app_state_kind.dart';
import 'state_illustration_color_mapper.dart';

class AppStateView extends StatelessWidget {
  const AppStateView({
    super.key,
    required this.kind,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
    this.illustrationSize,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
  });

  final AppStateKind kind;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;
  final double? illustrationSize;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.followTokens;
    final specification = _specifications[kind]!;

    return LayoutBuilder(
      builder: (context, constraints) {
        final resolvedIllustrationSize =
            illustrationSize ?? (constraints.maxWidth >= 800 ? 220.0 : 172.0);
        final resolvedPadding = padding.resolve(Directionality.of(context));
        final minimumContentHeight = constraints.hasBoundedHeight
            ? (constraints.maxHeight - resolvedPadding.vertical).clamp(
                0.0,
                double.infinity,
              )
            : 0.0;
        return SingleChildScrollView(
          padding: resolvedPadding,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minimumContentHeight),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SvgPicture.asset(
                      specification.assetPath,
                      width: resolvedIllustrationSize,
                      height: resolvedIllustrationSize,
                      fit: BoxFit.contain,
                      semanticsLabel: specification.semanticsLabel,
                      colorMapper: StateIllustrationColorMapper(tokens),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                    if (actionLabel != null && onAction != null) ...[
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: onAction,
                        child: Text(actionLabel!),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StateIllustrationSpecification {
  const _StateIllustrationSpecification({
    required this.assetPath,
    required this.semanticsLabel,
  });

  final String assetPath;
  final String semanticsLabel;
}

const _specifications = <AppStateKind, _StateIllustrationSpecification>{
  AppStateKind.emptyLibrary: _StateIllustrationSpecification(
    assetPath: 'assets/illustrations/state_empty_library.svg',
    semanticsLabel: '唱片环绕声波的空资料库插画',
  ),
  AppStateKind.emptyPlaylist: _StateIllustrationSpecification(
    assetPath: 'assets/illustrations/state_empty_playlist.svg',
    semanticsLabel: '两张等待连接的唱片插画',
  ),
  AppStateKind.noResults: _StateIllustrationSpecification(
    assetPath: 'assets/illustrations/state_no_results.svg',
    semanticsLabel: '扫描光束掠过唱片的无结果插画',
  ),
  AppStateKind.noLyrics: _StateIllustrationSpecification(
    assetPath: 'assets/illustrations/state_no_lyrics.svg',
    semanticsLabel: '唱片与空白歌词轨道插画',
  ),
  AppStateKind.emptyDownloads: _StateIllustrationSpecification(
    assetPath: 'assets/illustrations/state_empty_downloads.svg',
    semanticsLabel: '云端声波落入唱片的空下载插画',
  ),
  AppStateKind.offline: _StateIllustrationSpecification(
    assetPath: 'assets/illustrations/state_offline.svg',
    semanticsLabel: '断开的声波桥离线插画',
  ),
  AppStateKind.failure: _StateIllustrationSpecification(
    assetPath: 'assets/illustrations/state_failure.svg',
    semanticsLabel: '唱片偏离轨道的失败插画',
  ),
  AppStateKind.nothingPlaying: _StateIllustrationSpecification(
    assetPath: 'assets/illustrations/state_nothing_playing.svg',
    semanticsLabel: '静止唱片与未点亮唱臂插画',
  ),
};
