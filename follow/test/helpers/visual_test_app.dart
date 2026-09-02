import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow/core/theme/app_theme.dart';
import 'package:follow/core/theme/follow_theme_tokens.dart';
import 'package:follow/core/theme/player_palette.dart';
import 'package:follow/data/models/track.dart';
import 'package:follow/shared/widgets/player/player_aurora_background.dart';
import 'package:follow/shared/widgets/section_header.dart';
import 'package:follow/shared/widgets/states/app_state_kind.dart';
import 'package:follow/shared/widgets/states/app_state_view.dart';
import 'package:follow/shared/widgets/surfaces/aurora_background.dart';
import 'package:follow/shared/widgets/surfaces/glass_panel.dart';

const visualFixtureKey = ValueKey('visual-fixture');

class VisualTestApp extends StatelessWidget {
  const VisualTestApp({
    super.key,
    required this.themeMode,
    required this.child,
    this.disableAnimations = true,
  });

  final ThemeMode themeMode;
  final Widget child;
  final bool disableAnimations;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            disableAnimations: disableAnimations,
            accessibleNavigation: disableAnimations,
            textScaler: TextScaler.noScaling,
          ),
          child: child!,
        );
      },
      home: Scaffold(
        body: RepaintBoundary(key: visualFixtureKey, child: child),
      ),
    );
  }
}

Future<void> pumpVisualFixture(
  WidgetTester tester, {
  required Size surfaceSize,
  required ThemeMode themeMode,
  required Widget child,
}) async {
  await tester.binding.setSurfaceSize(surfaceSize);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(VisualTestApp(themeMode: themeMode, child: child));
  await tester.pump();
}

class DesignSystemComponentBoard extends StatelessWidget {
  const DesignSystemComponentBoard({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.followTokens;
    return AuroraBackground(
      child: BackdropGroup(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionHeader(
                  title: '沉浸式极光',
                  actionLabel: '查看全部',
                  onAction: _noop,
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(height: 16),
                Text(
                  '统一设计语言',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  '语义色彩、层级排版与克制的玻璃表面。',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                for (final tier in GlassTier.values) ...[
                  GlassPanel(
                    tier: tier,
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(_iconFor(tier), color: tokens.brandPrimary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${tier.name.toUpperCase()} GLASS',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        const Icon(Icons.graphic_eq_rounded),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 4),
                TextField(
                  readOnly: true,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded),
                    hintText: '搜索歌曲、专辑或艺人',
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _noop,
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('立即播放'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton.filledTonal(
                      onPressed: _noop,
                      icon: const Icon(Icons.favorite_border_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  children: [
                    _StatusDot(label: '在线', color: tokens.success),
                    _StatusDot(label: '提醒', color: tokens.warning),
                    _StatusDot(label: '离线', color: tokens.offline),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static IconData _iconFor(GlassTier tier) => switch (tier) {
    GlassTier.light => Icons.blur_on_rounded,
    GlassTier.standard => Icons.layers_rounded,
    GlassTier.strong => Icons.auto_awesome_rounded,
  };
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(Icons.circle, size: 10, color: color),
      label: Text(label),
    );
  }
}

class PlayerAuroraFixture extends StatelessWidget {
  const PlayerAuroraFixture({
    super.key,
    required this.palette,
    this.coverColor,
    this.failedCover = false,
  });

  final PlayerPalette palette;
  final Color? coverColor;
  final bool failedCover;

  @override
  Widget build(BuildContext context) {
    final hasCover = coverColor != null || failedCover;
    final track = hasCover
        ? const Track(
            id: 'golden-track',
            title: 'Northern Lights',
            coverUrl: 'covers/golden.bmp',
            artist: Artist(id: 'golden-artist', name: 'Follow Ensemble'),
          )
        : null;
    final provider = failedCover
        ? MemoryImage(Uint8List.fromList(const [0, 1, 2, 3]))
        : coverColor == null
        ? null
        : MemoryImage(solidBmp(coverColor!));

    return PlayerAuroraBackground(
      track: track,
      palette: palette,
      imageProviderOverride: provider,
      child: BackdropGroup(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final desktop = constraints.maxWidth >= 800;
              final compact = constraints.maxHeight < 700;
              final recordSize = desktop
                  ? 320.0
                  : compact
                  ? 220.0
                  : 280.0;
              final content = _PlayerContent(
                palette: palette,
                recordSize: recordSize,
                compact: compact,
              );
              if (!desktop) return content;
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: GlassPanel(
                    tier: GlassTier.standard,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 56,
                      vertical: 36,
                    ),
                    child: Row(
                      children: [
                        _Record(size: recordSize, palette: palette),
                        const SizedBox(width: 64),
                        Expanded(
                          child: _TrackControls(
                            palette: palette,
                            reserveRecordSpace: false,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PlayerContent extends StatelessWidget {
  const _PlayerContent({
    required this.palette,
    required this.recordSize,
    required this.compact,
  });

  final PlayerPalette palette;
  final double recordSize;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, compact ? 16 : 28, 24, 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(onPressed: _noop, icon: const Icon(Icons.expand_more)),
              Text('正在播放', style: Theme.of(context).textTheme.labelLarge),
              IconButton(onPressed: _noop, icon: const Icon(Icons.more_horiz)),
            ],
          ),
          SizedBox(height: compact ? 4 : 18),
          _Record(size: recordSize, palette: palette),
          const Spacer(),
          _TrackControls(palette: palette, reserveRecordSpace: true),
        ],
      ),
    );
  }
}

class _Record extends StatelessWidget {
  const _Record({required this.size, required this.palette});

  final double size;
  final PlayerPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF101116),
        border: Border.all(color: Colors.white24, width: 2),
        boxShadow: [
          BoxShadow(
            color: palette.glow.withValues(alpha: 0.35),
            blurRadius: 36,
          ),
        ],
        gradient: const SweepGradient(
          colors: [
            Color(0xFF090A0D),
            Color(0xFF292B31),
            Color(0xFF0C0D11),
            Color(0xFF24262B),
            Color(0xFF090A0D),
          ],
        ),
      ),
      child: Center(
        child: Container(
          width: size * 0.42,
          height: size * 0.42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [palette.secondary, palette.ambient],
            ),
          ),
          child: Center(
            child: Container(
              width: size * 0.055,
              height: size * 0.055,
              decoration: const BoxDecoration(
                color: Color(0xFFF4F2FA),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TrackControls extends StatelessWidget {
  const _TrackControls({
    required this.palette,
    required this.reserveRecordSpace,
  });

  final PlayerPalette palette;
  final bool reserveRecordSpace;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      tier: GlassTier.strong,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Northern Lights',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 2),
          Text(
            'Follow Ensemble',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          SizedBox(height: reserveRecordSpace ? 14 : 24),
          SliderTheme(
            data: Theme.of(context).sliderTheme.copyWith(
              activeTrackColor: palette.progress,
              thumbColor: palette.progress,
            ),
            child: const Slider(value: 0.42, onChanged: _noopDouble),
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Text('01:48'), Text('-02:31')],
          ),
          const SizedBox(height: 8),
          _VisualPlayerControls(palette: palette),
        ],
      ),
    );
  }
}

class _VisualPlayerControls extends StatelessWidget {
  const _VisualPlayerControls({required this.palette});

  final PlayerPalette palette;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const _SecondaryControl(icon: Icons.repeat_rounded),
          const _SecondaryControl(icon: Icons.skip_previous_rounded),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: palette.primaryControl,
              boxShadow: [
                BoxShadow(
                  color: palette.glow.withValues(alpha: 0.36),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(
              Icons.pause_rounded,
              color: palette.onPrimaryControl,
              size: 30,
            ),
          ),
          const _SecondaryControl(icon: Icons.skip_next_rounded),
          const _SecondaryControl(icon: Icons.queue_music_rounded),
        ],
      ),
    );
  }
}

class _SecondaryControl extends StatelessWidget {
  const _SecondaryControl({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final foreground = Theme.of(context).colorScheme.onSurface;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: foreground.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: foreground.withValues(alpha: 0.82), size: 22),
    );
  }
}

class StateViewsBoard extends StatelessWidget {
  const StateViewsBoard({super.key});

  static const _labels = <AppStateKind, (String, String)>{
    AppStateKind.emptyLibrary: ('资料库还是空的', '收藏喜欢的歌曲后会出现在这里'),
    AppStateKind.emptyPlaylist: ('歌单等待第一首歌', '从资料库加入想听的内容'),
    AppStateKind.noResults: ('没有找到结果', '试试更短或不同的关键词'),
    AppStateKind.noLyrics: ('暂时没有歌词', '仍然可以继续享受音乐'),
    AppStateKind.emptyDownloads: ('还没有下载', '下载后即可离线播放'),
    AppStateKind.offline: ('网络连接已断开', '恢复网络后再试一次'),
    AppStateKind.failure: ('加载没有完成', '稍后重试或检查连接'),
    AppStateKind.nothingPlaying: ('选择一首歌开始', '极光会随唱片封面变化'),
  };

  @override
  Widget build(BuildContext context) {
    return AuroraBackground(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: GridView.count(
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 4,
          childAspectRatio: 1.45,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: [
            for (final kind in AppStateKind.values)
              Card(
                clipBehavior: Clip.antiAlias,
                child: AppStateView(
                  kind: kind,
                  title: _labels[kind]!.$1,
                  description: _labels[kind]!.$2,
                  illustrationSize: 92,
                  padding: const EdgeInsets.all(10),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

PlayerPalette paletteForVisual({
  required ThemeMode themeMode,
  required Color secondary,
  required Color ambient,
}) {
  final dark = themeMode == ThemeMode.dark;
  final tokens = dark ? FollowThemeTokens.dark : FollowThemeTokens.light;
  return PlayerPalette.guard(
    candidatePrimary: dark ? const Color(0xFFA99CFF) : const Color(0xFF5B46F0),
    candidateOnPrimary: dark ? const Color(0xFF21145F) : Colors.white,
    candidateSecondary: secondary,
    candidateAmbient: ambient,
    brightness: dark ? Brightness.dark : Brightness.light,
    tokens: tokens,
  );
}

Uint8List solidBmp(Color color) {
  const width = 24;
  const height = 24;
  const rowSize = width * 3;
  const pixelOffset = 54;
  const fileSize = pixelOffset + rowSize * height;
  final data = ByteData(fileSize);
  data.setUint8(0, 0x42);
  data.setUint8(1, 0x4D);
  data.setUint32(2, fileSize, Endian.little);
  data.setUint32(10, pixelOffset, Endian.little);
  data.setUint32(14, 40, Endian.little);
  data.setInt32(18, width, Endian.little);
  data.setInt32(22, height, Endian.little);
  data.setUint16(26, 1, Endian.little);
  data.setUint16(28, 24, Endian.little);
  data.setUint32(34, rowSize * height, Endian.little);
  for (var offset = pixelOffset; offset < fileSize; offset += 3) {
    data.setUint8(offset, color.b.round());
    data.setUint8(offset + 1, color.g.round());
    data.setUint8(offset + 2, color.r.round());
  }
  return data.buffer.asUint8List();
}

void _noop() {}
void _noopDouble(double _) {}
