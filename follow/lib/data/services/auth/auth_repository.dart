import 'package:dio/dio.dart';
import 'package:follow/data/models/user.dart';
import 'package:follow/data/services/api/api_service.dart';
import 'package:follow/data/services/auth/secure_token_store.dart';

class AuthRepository {
  AuthRepository({
    required AuthApi api,
    required TokenStore tokenStore,
    required String deviceName,
    Future<void> Function()? clearAccountState,
  }) : _api = api,
       _tokenStore = tokenStore,
       _deviceName = deviceName,
       _clearAccountState = clearAccountState ?? _noAccountStateCleanup;

  final AuthApi _api;
  final TokenStore _tokenStore;
  final String _deviceName;
  final Future<void> Function() _clearAccountState;

  Future<User> login(String email, String password) async {
    final response = await _api.login(
      LoginRequest(
        email: email,
        password: password,
        tokenTransport: 'body',
        deviceName: _deviceName,
      ),
    );
    return _storeAuthResponse(response);
  }

  Future<User> register(String username, String email, String password) async {
    final response = await _api.register(
      RegisterRequest(
        username: username,
        email: email,
        password: password,
        tokenTransport: 'body',
        deviceName: _deviceName,
      ),
    );
    return _storeAuthResponse(response);
  }

  Future<bool> logout() async {
    try {
      await _api.logout();
    } catch (_) {
      // The interceptor clears rejected credentials before surfacing a final
      // 401. In that case the server has already told us this session is no
      // longer valid, so finish the local logout instead of restoring a stale
      // authenticated UI state.
      if (await _tokenStore.readTokens() == null) {
        await _clearAccountState();
        return true;
      }
      return false;
    }
    await clearLocalSession();
    return true;
  }

  Future<void> clearLocalSession() async {
    try {
      await _tokenStore.clearTokens();
    } finally {
      await _clearAccountState();
    }
  }

  Future<User?> restoreCurrentUser() async {
    if (await _tokenStore.readTokens() == null) return null;
    try {
      return await _api.getCurrentUser();
    } on DioException catch (error) {
      if (_isAuthenticationRejection(error)) {
        await clearLocalSession();
        return null;
      }
      rethrow;
    }
  }

  Future<User> _storeAuthResponse(AuthResponse response) async {
    await _tokenStore.writeTokens(
      AuthTokenPair(
        accessToken: response.accessToken,
        refreshToken: response.refreshToken,
        sessionId: response.sessionId,
      ),
    );
    return response.user;
  }
}

bool _isAuthenticationRejection(DioException error) {
  return switch (error.response?.statusCode) {
    400 || 401 || 409 => true,
    _ => false,
  };
}

Future<void> _noAccountStateCleanup() async {}
