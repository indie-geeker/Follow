import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:auto_route/auto_route.dart';
import 'package:follow/features/search/providers/search_provider.dart';
import 'package:follow/core/theme/follow_theme_tokens.dart';
import 'package:follow/shared/widgets/surfaces/glass_panel.dart';

import '../../../router/app_router.dart';

class SidebarSearchBox extends ConsumerStatefulWidget {
  const SidebarSearchBox({super.key});

  @override
  ConsumerState<SidebarSearchBox> createState() => _SidebarSearchBoxState();
}

class _SidebarSearchBoxState extends ConsumerState<SidebarSearchBox> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Sync with provider initially (e.g. if navigating back)
    _controller.text = ref.read(searchQueryProvider);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Listen to provider changes to keep sync if changed elsewhere
    ref.listen(searchQueryProvider, (previous, next) {
      if (_controller.text != next) {
        _controller.text = next;
      }
    });

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SizedBox(
        height: context.followTokens.minimumTapTarget,
        child: GlassPanel(
          tier: GlassTier.standard,
          borderRadius: BorderRadius.circular(context.followTokens.radiusInput),
          child: TextField(
            controller: _controller,
            style: TextStyle(
              color: isDark ? Colors.white : theme.colorScheme.onSurface,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              hintText: '搜索...',
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
              contentPadding: const EdgeInsets.symmetric(
                vertical: 0,
                horizontal: 8,
              ),
              border: InputBorder.none,
              isDense: true,
            ),
            onChanged: (value) {
              ref.read(searchQueryProvider.notifier).state = value;
              // Auto-navigate to search page if not already there
              if (context.router.current.name != SearchRoute.name) {
                context.router.push(const SearchRoute());
              }
            },
            onTap: () {
              if (context.router.current.name != SearchRoute.name) {
                context.router.push(const SearchRoute());
              }
            },
          ),
        ),
      ),
    );
  }
}
