import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/api_client.dart';
import '../../ui/snack.dart';
import '../../ui/user_avatar.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback onLogout;
  final VoidCallback? onProfileUpdated;

  const ProfileScreen({
    super.key,
    required this.onLogout,
    this.onProfileUpdated,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nicknameCtrl = TextEditingController();
  final _avatarCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  String _presence = 'на месте';
  bool _saving = false;

  static const _options = ['на месте', 'отошел', 'не беспокоить'];

  @override
  void initState() {
    super.initState();
    _fill();
  }

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    _avatarCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _fill() {
    final user = ApiClient.instance.currentUser;
    if (user == null) return;
    _nicknameCtrl.text = user['nickname']?.toString() ?? '';
    _avatarCtrl.text = user['avatar_url']?.toString() ?? '';
    final presence = user['presence_status']?.toString() ?? 'на месте';
    if (_options.contains(presence)) _presence = presence;
  }

  Future<void> _setPresence(String next) async {
    try {
      await ApiClient.instance.patch('/api/v1/users/me/presence', {
        'status': next,
      });
      await ApiClient.instance.refreshProfile();
      if (!mounted) return;
      setState(() => _presence = next);
      widget.onProfileUpdated?.call();
      showSnack(context, 'Статус: $next');
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), isError: true);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final avatar = _avatarCtrl.text.trim();
      final body = <String, dynamic>{
        'nickname': _nicknameCtrl.text.trim(),
        'avatar_url': avatar.isEmpty ? null : avatar,
      };
      if (_passwordCtrl.text.isNotEmpty) {
        body['password'] = _passwordCtrl.text;
      }
      await ApiClient.instance.patch('/api/v1/users/me', body);
      await ApiClient.instance.refreshProfile();
      _passwordCtrl.clear();
      _fill();
      if (!mounted) return;
      setState(() {});
      widget.onProfileUpdated?.call();
      showSnack(context, 'Сохранили');
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ApiClient.instance.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('Профиль')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Row(
            children: [
              UserAvatar(
                nickname: user?['nickname']?.toString() ?? '',
                avatarUrl: user?['avatar_url']?.toString(),
                radius: 28,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?['nickname']?.toString() ?? '',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user?['email']?.toString() ?? '',
                      style: const TextStyle(color: kMuted),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'id ${user?['user_id']} · ${user?['activity_status']}',
                      style: const TextStyle(color: kMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const Text('Статус', style: TextStyle(color: kMuted, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              for (final option in _options)
                GestureDetector(
                  onTap: () => _setPresence(option),
                  child: Text(
                    option,
                    style: TextStyle(
                      color: _presence == option ? kAccent : kMuted,
                      fontWeight: _presence == option
                          ? FontWeight.w600
                          : FontWeight.w400,
                      decoration: _presence == option
                          ? TextDecoration.underline
                          : null,
                      decorationColor: kAccent,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 22),
          TextField(
            controller: _nicknameCtrl,
            decoration: const InputDecoration(labelText: 'Псевдоним'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _avatarCtrl,
            decoration: const InputDecoration(
              labelText: 'Ссылка на аватар',
              hintText: 'https://…',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordCtrl,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Новый пароль',
              hintText: 'Пусто — не менять',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Сохраняем…' : 'Сохранить'),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: widget.onLogout,
            style: TextButton.styleFrom(foregroundColor: kBad),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
  }
}
