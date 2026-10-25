import 'dart:convert';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/api_client.dart';
import '../../ui/snack.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  List<dynamic> _users = [];
  List<dynamic> _teams = [];
  List<dynamic> _requests = [];
  List<dynamic> _logs = [];
  List<dynamic> _inspected = [];

  String? _error;
  bool _loading = true;

  final _searchCtrl = TextEditingController();
  final _unlockCtrl = TextEditingController();
  final _inspectCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    _unlockCtrl.dispose();
    _inspectCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_users.isEmpty &&
        _requests.isEmpty &&
        _teams.isEmpty &&
        _logs.isEmpty &&
        !_loading &&
        mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final api = ApiClient.instance;
      final query = _searchCtrl.text.trim();
      final res = await Future.wait([
        api.get('/api/v1/admin/users', {'q': query}),
        api.get('/api/v1/support/requests'),
        api.get('/api/v1/admin/teams'),
        api.get('/api/v1/admin/system-logs'),
      ]);
      if (!mounted) return;
      setState(() {
        _users = res[0] as List<dynamic>;
        _requests = res[1] as List<dynamic>;
        _teams = res[2] as List<dynamic>;
        _logs = res[3] as List<dynamic>;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword(Map<String, dynamic> user) async {
    try {
      final res = await ApiClient.instance.post(
        '/api/v1/admin/users/${user['user_id']}/password-reset',
      );
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(user['nickname']?.toString() ?? 'Пароль'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Временный пароль'),
              const SizedBox(height: 6),
              SelectableText(
                res['temporary_password'].toString(),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Закрыть'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), isError: true);
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> user, bool active) async {
    try {
      await ApiClient.instance.patch(
        '/api/v1/admin/users/${user['user_id']}/activity',
        {'active': !active},
      );
      await _load();
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), isError: true);
    }
  }

  Future<void> _toggleRequest(Map<String, dynamic> request, bool done) async {
    try {
      await ApiClient.instance.patch(
        '/api/v1/support/requests/${request['request_id']}',
        {'processed': !done},
      );
      await _load();
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), isError: true);
    }
  }

  Future<void> _unlockTask() async {
    final id = int.tryParse(_unlockCtrl.text.trim());
    if (id == null) return;
    try {
      await ApiClient.instance.post('/api/v1/admin/tasks/$id/unlock');
      if (mounted) showSnack(context, 'Задачу $id разблокировали');
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), isError: true);
    }
  }

  Future<void> _inspect() async {
    final id = int.tryParse(_inspectCtrl.text.trim());
    if (id == null) return;
    try {
      final list = await ApiClient.instance.get(
        '/api/v1/admin/tasks/$id/changes',
      );
      if (!mounted) return;
      setState(() => _inspected = list as List<dynamic>);
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = ApiClient.instance.currentUser?['user_id'];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Поддержка'),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Люди'),
            Tab(text: 'Заявки'),
            Tab(text: 'Задачи'),
            Tab(text: 'Журнал'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text(
                      'Ваш id: $myId. Сюда пускают только id из SUPPORT_USER_IDS.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: kMuted, height: 1.35),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _load,
                      child: const Text('Проверить снова'),
                    ),
                  ],
                ),
              ),
            )
          : TabBarView(
              controller: _tabs,
              children: [_usersTab(), _requestsTab(), _tasksTab(), _logsTab()],
            ),
    );
  }

  Widget _usersTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Псевдоним или почта',
                  ),
                  onSubmitted: (_) => _load(),
                ),
              ),
              TextButton(onPressed: _load, child: const Text('Найти')),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: _users.length,
            separatorBuilder: (_, _) => const Divider(height: 1, indent: 16),
            itemBuilder: (context, i) {
              final user = _users[i] as Map<String, dynamic>;
              final active = user['activity_status'] == 'активен';
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '#${user['user_id']} ${user['nickname']}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${user['email']} · ${user['presence_status']}',
                      style: const TextStyle(color: kMuted, fontSize: 13),
                    ),
                    Text(
                      user['activity_status']?.toString() ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: active ? kAccent : kBad,
                      ),
                    ),
                    Wrap(
                      spacing: 4,
                      children: [
                        TextButton(
                          onPressed: () => _resetPassword(user),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 0),
                          ),
                          child: const Text('Сбросить пароль'),
                        ),
                        TextButton(
                          onPressed: () => _toggleActive(user, active),
                          style: TextButton.styleFrom(
                            foregroundColor: active ? kBad : kAccent,
                          ),
                          child: Text(
                            active ? 'Заблокировать' : 'Разблокировать',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _requestsTab() {
    if (_requests.isEmpty) {
      return const Center(
        child: Text('Заявок нет', style: TextStyle(color: kMuted)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _requests.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 16),
      itemBuilder: (context, i) {
        final request = _requests[i] as Map<String, dynamic>;
        final done = request['processed_time'] != null;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '#${request['request_id']} ${request['subject']}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                request['text']?.toString() ?? '',
                style: const TextStyle(height: 1.35),
              ),
              const SizedBox(height: 4),
              Text(
                '${request['nickname']} · ${request['created_time']}',
                style: const TextStyle(color: kMuted, fontSize: 12),
              ),
              TextButton(
                onPressed: () => _toggleRequest(request, done),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(done ? 'Вернуть' : 'Готово'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _tasksTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        const Text(
          'Снять блокировку',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _unlockCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Номер задачи'),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: _unlockTask,
            child: const Text('Разблокировать'),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'История правок',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _inspectCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Номер задачи'),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(onPressed: _inspect, child: const Text('Показать')),
        ),
        for (final change in _inspected)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '#${change['change_id']} ${change['author']} · ${change['author_role']}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  change['diff_content']?.toString() ?? '',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 18),
        const Text(
          'Команды',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        const SizedBox(height: 8),
        for (final team in _teams)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '#${team['team_id']} ${team['name']}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  'владелец ${team['owner']} · ${team['created_time']}',
                  style: const TextStyle(color: kMuted, fontSize: 12),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _logsTab() {
    if (_logs.isEmpty) {
      return const Center(
        child: Text('Журнал пуст', style: TextStyle(color: kMuted)),
      );
    }
    const encoder = JsonEncoder.withIndent('  ');
    return ListView.separated(
      itemCount: _logs.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final log = _logs[i] as Map<String, dynamic>;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: SelectableText(
            encoder.convert(log),
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              height: 1.35,
              color: kInk,
            ),
          ),
        );
      },
    );
  }
}
