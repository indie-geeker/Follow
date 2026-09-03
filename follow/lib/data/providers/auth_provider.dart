import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:follow/data/models/user.dart';
import 'package:follow/data/providers/audio_provider.dart';
import 'package:follow/data/providers/download_provider.dart';
import 'package:follow/data/providers/history_provider.dart';
import 'package:follow/data/providers/lyrics_provider.dart';
import 'package:follow/data/providers/playlist_provider.dart';
import 'package:follow/data/providers/track_provider.dart';
import 'package:follow/data/services/api/api_client.dart';
import 'package:follow/data/services/api/api_service.dart';
import 'package:follow/data/services/auth/auth_repository.dart';
import 'package:follow/data/services/auth/client_device.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_provider.g.dart';

/// Authentication state
sealed class AuthState {
  const AuthState();
}

class AuthStateInitial extends AuthState {
  const AuthStateInitial();
}

class AuthStateLoading extends AuthState {
  const AuthStateLoading();
}

class AuthStateAuthenticated extends AuthState {
  final User user;
  const AuthStateAuthenticated(this.user);
}

class AuthStateUnauthenticated extends AuthState {
  const AuthStateUnauthenticated();
}

class AuthStateError extends AuthState {
  final String message;
  const AuthStateError(this.message);
}

/// Auth provider with Riverpod generator
@riverpod
class Auth extends _$Auth {
  late final AuthRepository _repository;

  @override
  AuthState build() {
    _repository = AuthRepository(
      api: ApiService(),
      tokenStore: ApiClient.tokenStore,
      deviceName: clientDeviceName(),
      clearAccountState: _clearAccountState,
    );
    unawaited(_checkAuth());
    return const AuthStateInitial();
  }

  Future<void> _checkAuth() async {
    state = const AuthStateLoading();
    try {
      final user = await _repository.restoreCurrentUser();
      state = user == null
          ? const AuthStateUnauthenticated()
          : AuthStateAuthenticated(user);
    } catch (error) {
      state = AuthStateError(_parseError(error));
    }
  }

  Future<void> login(String identifier, String password) async {
    state = const AuthStateLoading();

    try {
      final user = await _repository.login(identifier, password);
      state = AuthStateAuthenticated(user);
    } catch (e) {
      state = AuthStateError(_parseError(e));
    }
  }

  Future<void> register(String username, String email, String password) async {
    state = const AuthStateLoading();

    try {
      final user = await _repository.register(username, email, password);
      state = AuthStateAuthenticated(user);
    } catch (e) {
      state = AuthStateError(_parseError(e));
    }
  }

  Future<bool> logout() async {
    final previous = state;
    final revoked = await _repository.logout();
    if (revoked) {
      state = const AuthStateUnauthenticated();
      return true;
    }
    state = previous;
    return false;
  }

  Future<void> sessionExpired() async {
    try {
      await _repository.clearLocalSession();
    } finally {
      state = const AuthStateUnauthenticated();
    }
  }

  Future<void> _clearAccountState() async {
    try {
      await ref.read(audioPlayerServiceProvider).clearQueue();
    } catch (error) {
      debugPrint('Failed to clear playback state on logout: $error');
    }
    try {
      await ref.read(downloadManagerProvider.notifier).clearForLogout();
    } catch (error) {
      debugPrint('Failed to clear download request state on logout: $error');
    }
    ref.read(lyricsOverlayVisibleProvider.notifier).hide();
    ref.invalidate(downloadedTracksProvider);
    ref.invalidate(favoritesProvider);
    ref.invalidate(historyProvider);
    ref.invalidate(playlistsProvider);
    ref.invalidate(tracksProvider);
  }

  String _parseError(dynamic error) {
    if (error.toString().contains('401')) {
      return '用户名/邮箱或密码错误';
    }
    if (error.toString().contains('409')) {
      return '邮箱已被注册';
    }
    return '网络错误，请稍后重试';
  }
}

/// Check if authenticated
@riverpod
bool isAuthenticated(ref) {
  final authState = ref.watch(authProvider);
  return authState is AuthStateAuthenticated;
}

/// Get current user
@riverpod
User? currentUser(ref) {
  final authState = ref.watch(authProvider);
  if (authState is AuthStateAuthenticated) {
    return authState.user;
  }
  return null;
}
