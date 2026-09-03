import 'dart:math' as math;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:follow/core/l10n/l10n.dart';
import 'package:follow/core/theme/follow_theme_tokens.dart';
import 'package:follow/data/providers/auth_provider.dart';
import 'package:follow/data/services/auth/remembered_identifier_store.dart';
import 'package:follow/router/app_router.dart';
import 'package:follow/shared/widgets/surfaces/aurora_background.dart';
import 'package:follow/shared/widgets/surfaces/glass_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

@RoutePage()
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  bool _isLogin = true;
  bool _obscurePassword = true;
  bool _rememberIdentifier = false;

  // Animation controllers
  late AnimationController _logoController;
  late AnimationController _cardController;
  late AnimationController _shakeController;

  // Animations
  late Animation<double> _logoAnimation;
  late Animation<double> _cardAnimation;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadRememberedIdentifier();
  }

  void _initAnimations() {
    // Logo breathing animation
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
    _logoAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeInOut),
    );

    // Card entrance animation
    _cardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _cardAnimation = CurvedAnimation(
      parent: _cardController,
      curve: Curves.easeOutBack,
    );

    // Shake animation for validation errors
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
  }

  Future<void> _loadRememberedIdentifier() async {
    final prefs = await SharedPreferences.getInstance();
    final store = RememberedIdentifierStore(prefs);
    await store.migrateLegacyCredentials();
    final identifier = await store.read();
    if (!mounted || identifier == null) return;
    setState(() {
      _rememberIdentifier = true;
      _identifierController.text = identifier;
    });
  }

  Future<void> _saveRememberedIdentifier() async {
    final prefs = await SharedPreferences.getInstance();
    final store = RememberedIdentifierStore(prefs);
    if (_rememberIdentifier) {
      await store.save(_identifierController.text);
    } else {
      await store.clear();
    }
  }

  void _triggerShake() {
    _shakeController.reset();
    _shakeController.forward();
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    _logoController.dispose();
    _cardController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final authState = ref.watch(authProvider);

    // Listen for auth state changes
    ref.listen(authProvider, (prev, next) {
      if (next is AuthStateAuthenticated) {
        context.router.replaceAll([const MainShellRoute()]);
      } else if (next is AuthStateError) {
        _triggerShake();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.message),
            backgroundColor: context.followTokens.error,
          ),
        );
      }
    });

    final isLoading = authState is AuthStateLoading;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AuroraBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: AnimatedBuilder(
                animation: _cardAnimation,
                builder: (context, child) {
                  // Clamp opacity to valid range (easeOutBack can overshoot)
                  final opacity = _cardAnimation.value.clamp(0.0, 1.0);
                  return Transform.translate(
                    offset: Offset(0, 30 * (1 - _cardAnimation.value)),
                    child: Opacity(opacity: opacity, child: child),
                  );
                },
                child: _buildLoginCard(l10n, isLoading),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginCard(AppLocalizations l10n, bool isLoading) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: GlassPanel(
        tier: GlassTier.strong,
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated logo
              _buildAnimatedLogo(),
              const SizedBox(height: 20),

              // Title
              Text(
                'Follow Music',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: context.followTokens.textPrimary,
                  letterSpacing: 1,
                  shadows: [
                    Shadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Subtitle
              Text(
                _isLogin ? '欢迎回来' : '创建新账号',
                style: TextStyle(
                  fontSize: 15,
                  color: context.followTokens.textSecondary,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 36),

              // Username (register only)
              if (!_isLogin) ...[
                _buildShakeableTextField(
                  controller: _usernameController,
                  label: l10n.get('username'),
                  icon: Icons.person_outline,
                  validator: (v) {
                    if (!_isLogin &&
                        (v == null ||
                            v.trim().length < 3 ||
                            v.trim().length > 32)) {
                      return '用户名必须为3-32个字符';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
              ],

              if (_isLogin)
                _buildShakeableTextField(
                  controller: _identifierController,
                  label: l10n.get('loginIdentifier'),
                  icon: Icons.person_outline,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? '请输入用户名或邮箱' : null,
                )
              else
                _buildShakeableTextField(
                  controller: _emailController,
                  label: l10n.get('email'),
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || !v.contains('@')) {
                      return '请输入有效邮箱';
                    }
                    return null;
                  },
                ),
              const SizedBox(height: 20),

              // Password
              _buildShakeableTextField(
                controller: _passwordController,
                label: l10n.get('password'),
                icon: Icons.lock_outline,
                obscureText: _obscurePassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: context.followTokens.textSecondary,
                  ),
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
                validator: (v) {
                  if (v == null || (_isLogin && v.length < 6)) {
                    return '密码至少6个字符';
                  }
                  if (!_isLogin && (v.length < 6 || v.length > 128)) {
                    return '密码必须为6-128个字符';
                  }
                  if (!_isLogin &&
                      (!RegExp(r'[A-Z]').hasMatch(v) ||
                          !RegExp(r'[a-z]').hasMatch(v) ||
                          !RegExp(r'[0-9]').hasMatch(v) ||
                          !RegExp(r'[^A-Za-z0-9]').hasMatch(v) ||
                          RegExp(r'\s').hasMatch(v))) {
                    return '密码需包含大小写字母、数字和特殊字符，且不能有空格';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Remember account identifier checkbox (login only)
              if (_isLogin)
                Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _rememberIdentifier,
                        onChanged: (value) {
                          setState(() => _rememberIdentifier = value ?? false);
                        },
                        side: BorderSide(
                          color: context.followTokens.textSecondary,
                          width: 1.5,
                        ),
                        checkColor: Colors.white,
                        activeColor: context.followTokens.brandPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        setState(
                          () => _rememberIdentifier = !_rememberIdentifier,
                        );
                      },
                      child: Text(
                        l10n.get('rememberIdentifier'),
                        style: TextStyle(
                          color: context.followTokens.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 28),

              // Login button
              _buildGradientButton(
                label: _isLogin ? l10n.login : l10n.get('register'),
                isLoading: isLoading,
                onPressed: _submit,
              ),
              const SizedBox(height: 20),

              // Toggle login/register
              TextButton(
                onPressed: () {
                  setState(() => _isLogin = !_isLogin);
                },
                child: Text(
                  _isLogin ? '没有账号？注册' : '已有账号？登录',
                  style: TextStyle(
                    color: context.followTokens.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Footer
              Text(
                '© 2026 Follow Music. All rights reserved.',
                style: TextStyle(
                  color: context.followTokens.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedLogo() {
    return AnimatedBuilder(
      animation: _logoAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _logoAnimation.value,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  context.followTokens.brandPrimary,
                  context.followTokens.brandSecondary,
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: context.followTokens.brandPrimary.withValues(
                    alpha: 0.4,
                  ),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.music_note_rounded,
              size: 40,
              color: Colors.white,
            ),
          ),
        );
      },
    );
  }

  /// Wraps a text field with shake animation
  Widget _buildShakeableTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        final shake = math.sin(_shakeAnimation.value * math.pi * 4) * 8;
        return Transform.translate(offset: Offset(shake, 0), child: child);
      },
      child: _buildTextField(
        controller: controller,
        label: label,
        icon: icon,
        keyboardType: keyboardType,
        obscureText: obscureText,
        suffixIcon: suffixIcon,
        validator: validator,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: TextStyle(color: context.followTokens.textPrimary, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: context.followTokens.textSecondary),
        prefixIcon: Icon(icon, color: context.followTokens.textSecondary),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: context.followTokens.surfaceElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: context.followTokens.glassStandard.border,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: context.followTokens.glassStandard.border,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: context.followTokens.brandPrimary,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade400),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade400, width: 2),
        ),
        errorStyle: TextStyle(color: Colors.red.shade300),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildGradientButton({
    required String label,
    required bool isLoading,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              context.followTokens.brandPrimary,
              context.followTokens.brandSecondary,
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: context.followTokens.brandPrimary.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 4,
                  ),
                ),
        ),
      ),
    );
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) {
      _triggerShake();
      return;
    }

    if (_isLogin) {
      await _saveRememberedIdentifier();
      await ref
          .read(authProvider.notifier)
          .login(_identifierController.text.trim(), _passwordController.text);
    } else {
      await ref
          .read(authProvider.notifier)
          .register(
            _usernameController.text.trim(),
            _emailController.text.trim(),
            _passwordController.text,
          );
    }
  }
}
