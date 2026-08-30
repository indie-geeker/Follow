import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:follow/core/theme/app_theme.dart';
import 'package:follow/core/theme/theme_provider.dart';
import 'package:follow/core/l10n/l10n.dart';
import 'package:follow/router/app_router.dart';
import 'package:follow/data/providers/audio_provider.dart';
import 'package:follow/data/providers/auth_provider.dart';
import 'package:follow/data/services/api/api_client.dart';

class FollowApp extends ConsumerStatefulWidget {
  const FollowApp({super.key});

  @override
  ConsumerState<FollowApp> createState() => _FollowAppState();
}

class _FollowAppState extends ConsumerState<FollowApp> {
  late final AppRouter _appRouter;
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    _appRouter = AppRouter();

    // Setup callback for handling unauthorized (401) errors
    ApiClient.onUnauthorized = () {
      ref.read(authProvider.notifier).sessionExpired();
    };
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(appThemeModeProvider);
    final locale = ref.watch(appLocaleProvider);

    ref.listen<String?>(playbackFailureProvider, (previous, next) {
      if (next == null || next == previous) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final messenger = _scaffoldMessengerKey.currentState;
        if (messenger == null) return;
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(next)));
        ref.read(playbackFailureProvider.notifier).clear();
      });
    });

    // Listen to auth state changes
    ref.listen<AuthState>(authProvider, (previous, next) {
      // Navigate to login whenever the user becomes unauthenticated
      // This covers explicit logout, token expiration (401), etc.
      if (next is AuthStateUnauthenticated) {
        // Use replaceAll to clear the stack and prevent back navigation
        _appRouter.replaceAll([const LoginRoute()]);
      }
    });

    return MaterialApp.router(
      title: 'Follow Music',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _scaffoldMessengerKey,
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
