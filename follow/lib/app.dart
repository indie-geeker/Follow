import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:follow/core/theme/app_theme.dart';
import 'package:follow/core/theme/theme_provider.dart';
import 'package:follow/core/l10n/l10n.dart';
import 'package:follow/router/app_router.dart';

class FollowApp extends ConsumerStatefulWidget {
  const FollowApp({super.key});

  @override
  ConsumerState<FollowApp> createState() => _FollowAppState();
}

class _FollowAppState extends ConsumerState<FollowApp> {
  late final AppRouter _appRouter;

  @override
  void initState() {
    super.initState();
    _appRouter = AppRouter();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(appThemeModeProvider);
    final locale = ref.watch(appLocaleProvider);

    return MaterialApp.router(
      title: 'Follow Music',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: _appRouter.config(),
    );
  }
}
