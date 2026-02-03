import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:follow/core/l10n/l10n.dart';
import 'package:follow/core/theme/app_theme.dart';
import 'package:follow/core/theme/theme_provider.dart';
import 'package:follow/data/providers/auth_provider.dart';
import 'package:follow/data/providers/download_provider.dart';

@RoutePage()
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themeMode = ref.watch(appThemeModeProvider);
    final locale = ref.watch(appLocaleProvider);
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Full-screen gradient background
          if (isDark)
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    LoginColors.gradientEnd,
                    LoginColors.gradientMid2,
                    LoginColors.gradientMid1,
                    LoginColors.gradientStart,
                  ],
                ),
              ),
            ),

          // Content
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 100),
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: Text(
                    l10n.settings,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : theme.colorScheme.onSurface,
                    ),
                  ),
                ),

                // Appearance section
                _SectionCard(
                  isDark: isDark,
                  children: [
                    _SectionHeader(title: l10n.get('appearance'), isDark: isDark),
                    _SettingsTile(
                      icon: Icons.palette_outlined,
                      title: l10n.theme,
                      subtitle: _getThemeName(themeMode, l10n),
                      onTap: () => _showThemeDialog(context, ref, themeMode, l10n, isDark),
                      isDark: isDark,
                    ),
                    _SettingsTile(
                      icon: Icons.language_rounded,
                      title: l10n.language,
                      subtitle: locale.languageCode == 'zh' ? '中文' : 'English',
                      onTap: () => _showLanguageDialog(context, ref, locale, isDark),
                      isDark: isDark,
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Storage section
                _SectionCard(
                  isDark: isDark,
                  children: [
                    _SectionHeader(title: '存储', isDark: isDark),
                    Consumer(
                      builder: (context, ref, _) {
                        final downloadPathAsync = ref.watch(downloadPathProvider);
                        return _SettingsTile(
                          icon: Icons.folder_outlined,
                          title: '下载位置',
                          subtitle: downloadPathAsync.when(
                            data: (path) => _truncatePath(path, 30),
                            loading: () => '...',
                            error: (_, __) => '加载失败',
                          ),
                          onTap: () => _showDownloadPathDialog(context, ref, isDark, downloadPathAsync.value),
                          isDark: isDark,
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Account section
                _SectionCard(
                  isDark: isDark,
                  children: [
                    _SectionHeader(title: l10n.get('account'), isDark: isDark),
                    if (user != null) ...[
                      _UserTile(user: user, isDark: isDark),
                      _SettingsTile(
                        icon: Icons.logout_rounded,
                        title: l10n.logout,
                        isDestructive: true,
                        onTap: () => _confirmLogout(context, ref, isDark),
                        isDark: isDark,
                      ),
                    ] else
                      _SettingsTile(
                        icon: Icons.login_rounded,
                        title: l10n.login,
                        onTap: () => context.router.pushPath('/login'),
                        isDark: isDark,
                      ),
                  ],
                ),

                const SizedBox(height: 16),

                // About section
                _SectionCard(
                  isDark: isDark,
                  children: [
                    _SectionHeader(title: '关于', isDark: isDark),
                    _SettingsTile(
                      icon: Icons.info_outline_rounded,
                      title: '版本',
                      subtitle: '0.1.0',
                      showArrow: false,
                      isDark: isDark,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getThemeName(ThemeMode mode, AppLocalizations l10n) {
    switch (mode) {
      case ThemeMode.light:
        return l10n.get('light');
      case ThemeMode.dark:
        return l10n.get('dark');
      case ThemeMode.system:
        return l10n.get('system');
    }
  }

  String _truncatePath(String path, int maxLength) {
    if (path.length <= maxLength) return path;
    // Show last part of path
    final parts = path.split('/');
    String result = '';
    for (int i = parts.length - 1; i >= 0; i--) {
      final newResult = parts.sublist(i).join('/');
      if (newResult.length > maxLength) break;
      result = newResult;
    }
    return '.../$result';
  }

  void _showDownloadPathDialog(BuildContext context, WidgetRef ref, bool isDark, String? currentPath) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? LoginColors.gradientMid1 : null,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark ? LoginColors.textSecondary : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Column(
                  children: [
                    Text(
                      '下载位置',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    if (currentPath != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        currentPath,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? LoginColors.textSecondary : Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
              _DialogOption(
                title: '更改位置',
                icon: Icons.folder_open_rounded,
                selected: false,
                isDark: isDark,
                onTap: () async {
                  Navigator.pop(ctx);
                  await ref.read(downloadPathProvider.notifier).pickDownloadFolder();
                },
              ),
              _DialogOption(
                title: '打开文件夹',
                icon: Icons.open_in_new_rounded,
                selected: false,
                isDark: isDark,
                onTap: () {
                  Navigator.pop(ctx);
                  ref.read(downloadPathProvider.notifier).openDownloadFolder();
                },
              ),
              _DialogOption(
                title: '恢复默认',
                icon: Icons.restore_rounded,
                selected: false,
                isDark: isDark,
                onTap: () async {
                  Navigator.pop(ctx);
                  await ref.read(downloadPathProvider.notifier).resetToDefault();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showThemeDialog(BuildContext context, WidgetRef ref, ThemeMode current, AppLocalizations l10n, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? LoginColors.gradientMid1 : null,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark ? LoginColors.textSecondary : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  l10n.theme,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              _DialogOption(
                title: l10n.get('system'),
                icon: Icons.brightness_auto_rounded,
                selected: current == ThemeMode.system,
                isDark: isDark,
                onTap: () {
                  ref.read(appThemeModeProvider.notifier).setThemeMode(ThemeMode.system);
                  Navigator.pop(ctx);
                },
              ),
              _DialogOption(
                title: l10n.get('light'),
                icon: Icons.light_mode_rounded,
                selected: current == ThemeMode.light,
                isDark: isDark,
                onTap: () {
                  ref.read(appThemeModeProvider.notifier).setThemeMode(ThemeMode.light);
                  Navigator.pop(ctx);
                },
              ),
              _DialogOption(
                title: l10n.get('dark'),
                icon: Icons.dark_mode_rounded,
                selected: current == ThemeMode.dark,
                isDark: isDark,
                onTap: () {
                  ref.read(appThemeModeProvider.notifier).setThemeMode(ThemeMode.dark);
                  Navigator.pop(ctx);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showLanguageDialog(BuildContext context, WidgetRef ref, Locale current, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? LoginColors.gradientMid1 : null,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark ? LoginColors.textSecondary : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  '语言 / Language',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              _DialogOption(
                title: '中文',
                icon: Icons.translate_rounded,
                selected: current.languageCode == 'zh',
                isDark: isDark,
                onTap: () {
                  ref.read(appLocaleProvider.notifier).setLocale(const Locale('zh', 'CN'));
                  Navigator.pop(ctx);
                },
              ),
              _DialogOption(
                title: 'English',
                icon: Icons.translate_rounded,
                selected: current.languageCode == 'en',
                isDark: isDark,
                onTap: () {
                  ref.read(appLocaleProvider.notifier).setLocale(const Locale('en', 'US'));
                  Navigator.pop(ctx);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? LoginColors.gradientMid1 : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '确认退出',
          style: TextStyle(
            color: isDark ? Colors.white : null,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          '确定要退出登录吗？',
          style: TextStyle(
            color: isDark ? LoginColors.textSecondary : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              '取消',
              style: TextStyle(
                color: isDark ? LoginColors.textSecondary : null,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              ref.read(authProvider.notifier).logout();
              Navigator.pop(ctx);
            },
            child: const Text(
              '退出',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final List<Widget> children;
  final bool isDark;

  const _SectionCard({required this.children, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark
            ? LoginColors.cardBackground
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: isDark ? Border.all(color: LoginColors.cardBorder) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final bool isDark;

  const _SectionHeader({required this.title, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [LoginColors.accentPurple, LoginColors.accentPink],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? LoginColors.accentPurple : Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool isDestructive;
  final bool showArrow;
  final bool isDark;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.isDestructive = false,
    this.showArrow = true,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive
        ? Colors.red
        : (isDark ? Colors.white : Theme.of(context).colorScheme.onSurface);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDestructive
              ? Colors.red.withValues(alpha: 0.15)
              : (isDark
                  ? LoginColors.accentPurple.withValues(alpha: 0.2)
                  : Theme.of(context).colorScheme.primaryContainer),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: isDestructive
              ? Colors.red
              : (isDark ? LoginColors.accentPurple : Theme.of(context).colorScheme.primary),
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: TextStyle(
                color: isDark
                    ? LoginColors.textSecondary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            )
          : null,
      trailing: showArrow && onTap != null
          ? Icon(
              Icons.chevron_right_rounded,
              color: isDark
                  ? LoginColors.textSecondary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            )
          : null,
      onTap: onTap,
    );
  }
}

class _UserTile extends StatelessWidget {
  final dynamic user;
  final bool isDark;

  const _UserTile({required this.user, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [LoginColors.accentPurple, LoginColors.accentPink],
          ),
          boxShadow: [
            BoxShadow(
              color: LoginColors.accentPurple.withValues(alpha: 0.3),
              blurRadius: 8,
            ),
          ],
        ),
        child: CircleAvatar(
          radius: 22,
          backgroundColor: Colors.transparent,
          child: Text(
            user.username[0].toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
      ),
      title: Text(
        user.username,
        style: TextStyle(
          color: isDark ? Colors.white : Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        user.email,
        style: TextStyle(
          color: isDark
              ? LoginColors.textSecondary
              : Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _DialogOption extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _DialogOption({
    required this.title,
    required this.icon,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: selected
              ? LoginColors.accentPurple.withValues(alpha: 0.2)
              : (isDark ? LoginColors.cardBackground : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: selected
              ? LoginColors.accentPurple
              : (isDark ? LoginColors.textSecondary : Colors.grey.shade600),
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: selected
              ? LoginColors.accentPurple
              : (isDark ? Colors.white : Theme.of(context).colorScheme.onSurface),
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
      trailing: selected
          ? const Icon(Icons.check_rounded, color: LoginColors.accentPurple)
          : null,
      onTap: onTap,
    );
  }
}
