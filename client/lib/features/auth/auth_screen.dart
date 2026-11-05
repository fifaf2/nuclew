import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/api_client.dart';
import '../../ui/snack.dart';

class AuthScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const AuthScreen({super.key, required this.onLoginSuccess});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLogin = true;
  bool _loading = false;

  final _loginCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  @override
  void dispose() {
    _loginCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      final api = ApiClient.instance;
      final Map<String, dynamic> res;
      if (_isLogin) {
        res = await api.post('/api/v1/auth/login', {
          'login': _loginCtrl.text.trim(),
          'password': _passwordCtrl.text,
        });
      } else {
        res = await api.post('/api/v1/auth/register', {
          'nickname': _loginCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'password': _passwordCtrl.text,
        });
      }
      api.token = res['access_token'];
      await api.refreshProfile();
      widget.onLoginSuccess();
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openServerDialog() {
    final ctrl = TextEditingController(text: ApiClient.instance.baseUrl);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Сервер'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                labelText: 'Адрес',
                hintText: 'http://10.0.2.2:8000',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'На эмуляторе хост — 10.0.2.2, не 127.0.0.1.',
              style: TextStyle(color: kMuted, fontSize: 13, height: 1.3),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () => ctrl.text = 'http://127.0.0.1:8000',
                  child: const Text('Этот компьютер'),
                ),
                TextButton(
                  onPressed: () => ctrl.text = 'http://10.0.2.2:8000',
                  child: const Text('Эмулятор'),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              final cleaned = ctrl.text.trim().replaceAll(RegExp(r'/$'), '');
              ApiClient.instance.baseUrl = cleaned;
              Navigator.pop(ctx);
              showSnack(context, 'Сервер: $cleaned');
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _showForgotPassword() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Пароль'),
        content: const Text(
          'Сбросить его можно только через поддержку. Пока не вошли — сами не поменяете.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Понятно'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 36, 22, 24),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'nuclew',
                      style: TextStyle(
                        fontSize: 15,
                        letterSpacing: 0.6,
                        color: kAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      _isLogin ? 'Вход' : 'Регистрация',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        height: 1.1,
                        color: kInk,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isLogin
                          ? 'Почта или псевдоним.'
                          : 'Псевдоним, почта и пароль от 8 символов.',
                      style: const TextStyle(color: kMuted, height: 1.35),
                    ),
                    const SizedBox(height: 22),
                    TextField(
                      controller: _loginCtrl,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: _isLogin
                            ? 'Почта или псевдоним'
                            : 'Псевдоним',
                      ),
                    ),
                    if (!_isLogin) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(labelText: 'Почта'),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passwordCtrl,
                      obscureText: true,
                      onSubmitted: (_) => _loading ? null : _submit(),
                      decoration: const InputDecoration(labelText: 'Пароль'),
                    ),
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(_isLogin ? 'Войти' : 'Зарегистрироваться'),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => setState(() => _isLogin = !_isLogin),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 0),
                          ),
                          child: Text(
                            _isLogin ? 'Нет аккаунта' : 'Уже есть аккаунт',
                          ),
                        ),
                        const Spacer(),
                        if (_isLogin)
                          TextButton(
                            onPressed: _showForgotPassword,
                            style: TextButton.styleFrom(
                              foregroundColor: kMuted,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 0,
                              ),
                            ),
                            child: const Text('Забыли пароль?'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: _openServerDialog,
                        style: TextButton.styleFrom(
                          foregroundColor: kMuted,
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(ApiClient.instance.baseUrl),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
