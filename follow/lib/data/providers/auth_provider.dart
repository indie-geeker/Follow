import 'package:follow/data/models/user.dart';
import 'package:follow/data/services/api/api_client.dart';
import 'package:follow/data/services/api/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  late final ApiService _apiService;

  @override
  AuthState build() {
    _apiService = ApiService();
    _checkAuth();
    return const AuthStateInitial();
  }

  Future<void> _checkAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    
    if (token != null) {
      state = const AuthStateLoading();
      try {
        final user = await _apiService.getCurrentUser();
        state = AuthStateAuthenticated(user);
      } catch (e) {
        await prefs.remove('accessToken');
        await prefs.remove('refreshToken');
        state = const AuthStateUnauthenticated();
      }
    } else {
      state = const AuthStateUnauthenticated();
    }
  }

  Future<void> login(String email, String password) async {
    state = const AuthStateLoading();

    try {
      final response = await _apiService.login(LoginRequest(
        email: email,
        password: password,
      ));

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('accessToken', response.accessToken);
      await prefs.setString('refreshToken', response.refreshToken);

      state = AuthStateAuthenticated(response.user);
    } catch (e) {
      state = AuthStateError(_parseError(e));
    }
  }

  Future<void> register(String username, String email, String password) async {
    state = const AuthStateLoading();

    try {
      final response = await _apiService.register(RegisterRequest(
        username: username,
        email: email,
        password: password,
      ));

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('accessToken', response.accessToken);
      await prefs.setString('refreshToken', response.refreshToken);

      state = AuthStateAuthenticated(response.user);
    } catch (e) {
      state = AuthStateError(_parseError(e));
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('accessToken');
    await prefs.remove('refreshToken');
    ApiClient.resetInstance();
    state = const AuthStateUnauthenticated();
  }

  String _parseError(dynamic error) {
    if (error.toString().contains('401')) {
      return '邮箱或密码错误';
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
