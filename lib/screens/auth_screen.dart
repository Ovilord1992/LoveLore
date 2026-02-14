import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLogin = true;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final name = _nameController.text.trim();

    if (email.isEmpty || password.isEmpty) return;

    final authService = ref.read(authServiceProvider.notifier);
    bool success;

    if (_isLogin) {
      success = await authService.login(email, password);
    } else {
      success = await authService.register(
        email,
        password,
        displayName: name.isNotEmpty ? name : null,
      );
    }

    if (success && mounted) {
      final syncService = ref.read(syncServiceProvider);
      await syncService.pullAll();
      if (mounted) Navigator.of(context).pop(true);
    }
  }

  Future<void> _loginWithGoogle() async {
    final authService = ref.read(authServiceProvider.notifier);
    final success = await authService.loginWithGoogle();
    if (success && mounted) {
      final syncService = ref.read(syncServiceProvider);
      await syncService.pullAll();
      if (mounted) Navigator.of(context).pop(true);
    }
  }

  Future<void> _loginWithApple() async {
    final authService = ref.read(authServiceProvider.notifier);
    final success = await authService.loginWithApple();
    if (success && mounted) {
      final syncService = ref.read(syncServiceProvider);
      await syncService.pullAll();
      if (mounted) Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authServiceProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: Text(_isLogin ? 'Вход' : 'Регистрация'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              // Лого
              const Icon(
                Icons.auto_stories,
                size: 64,
                color: Color(0xFFE91E8C),
              ),
              const SizedBox(height: 16),
              Text(
                'Amoria',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                _isLogin
                    ? 'Войдите, чтобы сохранять прогресс'
                    : 'Создайте аккаунт',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white54,
                    ),
              ),
              const SizedBox(height: 48),

              // Имя (только при регистрации)
              if (!_isLogin) ...[
                _buildTextField(
                  controller: _nameController,
                  label: 'Имя',
                  icon: Icons.person_outline,
                ),
                const SizedBox(height: 16),
              ],

              // Email
              _buildTextField(
                controller: _emailController,
                label: 'Email',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),

              // Пароль
              _buildTextField(
                controller: _passwordController,
                label: 'Пароль',
                icon: Icons.lock_outlined,
                obscure: _obscurePassword,
                suffix: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off
                        : Icons.visibility,
                    color: Colors.white38,
                  ),
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
              ),
              const SizedBox(height: 8),

              // Ошибка
              if (authState.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    authState.error!,
                    style: const TextStyle(color: Colors.redAccent),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 24),

              // Кнопка входа/регистрации
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: authState.isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE91E8C),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: authState.isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          _isLogin ? 'Войти' : 'Зарегистрироваться',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // Переключатель вход/регистрация
              TextButton(
                onPressed: () {
                  setState(() => _isLogin = !_isLogin);
                },
                child: Text(
                  _isLogin
                      ? 'Нет аккаунта? Зарегистрируйтесь'
                      : 'Уже есть аккаунт? Войдите',
                  style: const TextStyle(color: Color(0xFFE91E8C)),
                ),
              ),

              const SizedBox(height: 24),

              // Разделитель
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.white24)),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('или', style: TextStyle(color: Colors.white38)),
                  ),
                  Expanded(child: Divider(color: Colors.white24)),
                ],
              ),
              const SizedBox(height: 24),

              // Google Sign-In
              SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: authState.isLoading ? null : _loginWithGoogle,
                  icon: const Text('G', style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold,
                    color: Colors.white,
                  )),
                  label: const Text('Войти через Google'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),

              // Apple Sign-In (только iOS)
              if (Platform.isIOS || Platform.isMacOS) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: authState.isLoading ? null : _loginWithApple,
                    icon: const Icon(Icons.apple, color: Colors.white),
                    label: const Text('Войти через Apple'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.white.withValues(alpha: 0.05),
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // Кнопка «без аккаунта»
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text(
                  'Продолжить без аккаунта',
                  style: TextStyle(color: Colors.white38),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white38),
        prefixIcon: Icon(icon, color: Colors.white38),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.08),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE91E8C)),
        ),
      ),
    );
  }
}
