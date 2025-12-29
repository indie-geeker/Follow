import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:follow/core/l10n/l10n.dart';
import 'package:follow/core/theme/theme_provider.dart';
import 'package:follow/data/providers/auth_provider.dart';

@RoutePage()
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final themeMode = ref.watch(appThemeModeProvider);
    final locale = ref.watch(appLocaleProvider);
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
      ),
      body: ListView(
        children: [
          // Appearance section
          _SectionHeader(title: l10n.get('appearance')),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: Text(l10n.theme),
            subtitle: Text(_getThemeName(themeMode, l10n)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showThemeDialog(context, ref, themeMode, l10n),
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(l10n.language),
            subtitle: Text(locale.languageCode == 'zh' ? '中文' : 'English'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showLanguageDialog(context, ref, locale),
          ),

          const Divider(),

          // Account section
          _SectionHeader(title: l10n.get('account')),
          if (user != null) ...[
            ListTile(
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Text(
                  user.username[0].toUpperCase(),
                  style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
                ),
              ),
              title: Text(user.username),
              subtitle: Text(user.email),
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: Text(
                l10n.logout,
                style: const TextStyle(color: Colors.red),
              ),
              onTap: () => _confirmLogout(context, ref),
            ),
          ] else ...[
            ListTile(
              leading: const Icon(Icons.login),
              title: Text(l10n.login),
              onTap: () => context.router.pushPath('/login'),
            ),
          ],

          const Divider(),

          // About section
          _SectionHeader(title: '关于'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('版本'),
            subtitle: Text('0.1.0'),
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

  void _showThemeDialog(BuildContext context, WidgetRef ref, ThemeMode current, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.theme),
        children: [
          _DialogOption(
            title: l10n.get('system'),
            selected: current == ThemeMode.system,
            onTap: () {
              ref.read(appThemeModeProvider.notifier).setThemeMode(ThemeMode.system);
              Navigator.pop(ctx);
            },
          ),
          _DialogOption(
            title: l10n.get('light'),
            selected: current == ThemeMode.light,
            onTap: () {
              ref.read(appThemeModeProvider.notifier).setThemeMode(ThemeMode.light);
              Navigator.pop(ctx);
            },
          ),
          _DialogOption(
            title: l10n.get('dark'),
            selected: current == ThemeMode.dark,
            onTap: () {
              ref.read(appThemeModeProvider.notifier).setThemeMode(ThemeMode.dark);
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog(BuildContext context, WidgetRef ref, Locale current) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('语言 / Language'),
        children: [
          _DialogOption(
            title: '中文',
            selected: current.languageCode == 'zh',
            onTap: () {
              ref.read(appLocaleProvider.notifier).setLocale(const Locale('zh', 'CN'));
              Navigator.pop(ctx);
            },
          ),
          _DialogOption(
            title: 'English',
            selected: current.languageCode == 'en',
            onTap: () {
              ref.read(appLocaleProvider.notifier).setLocale(const Locale('en', 'US'));
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认退出'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              ref.read(authProvider.notifier).logout();
              Navigator.pop(ctx);
            },
            child: const Text('退出', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _DialogOption extends StatelessWidget {
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const _DialogOption({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_off,
        color: selected ? Theme.of(context).colorScheme.primary : null,
      ),
      title: Text(
        title,
        style: selected ? TextStyle(color: Theme.of(context).colorScheme.primary) : null,
      ),
      onTap: onTap,
    );
  }
}
