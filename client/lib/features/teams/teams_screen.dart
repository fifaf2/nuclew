import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/api_client.dart';
import '../../ui/snack.dart';
import 'workspace_screen.dart';

class TeamsScreen extends StatefulWidget {
  const TeamsScreen({super.key});

  @override
  State<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends State<TeamsScreen> {
  List<dynamic> _teams = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_teams.isEmpty && !_loading && mounted) {
      setState(() => _loading = true);
    }
    try {
      final data = await ApiClient.instance.get('/api/v1/teams');
      if (!mounted) return;
      setState(() => _teams = data as List<dynamic>);
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createTeam() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Новая команда'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Название'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Описание'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) {
                showSnack(context, 'Нужно название', isError: true);
                return;
              }
              try {
                final desc = descCtrl.text.trim();
                await ApiClient.instance.post('/api/v1/teams', {
                  'name': name,
                  'description': desc.isEmpty ? null : desc,
                });
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                await _load();
                if (mounted) showSnack(context, 'Команда создана');
              } catch (e) {
                if (mounted) showSnack(context, e.toString(), isError: true);
              }
            },
            child: const Text('Создать'),
          ),
        ],
      ),
    );
  }

  Future<void> _joinByCode() async {
    final codeCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Код приглашения'),
        content: TextField(
          controller: codeCtrl,
          decoration: const InputDecoration(labelText: 'Код'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () async {
              final code = codeCtrl.text.trim();
              if (code.isEmpty) {
                showSnack(context, 'Введите код', isError: true);
                return;
              }
              try {
                await ApiClient.instance.post('/api/v1/invitations/join', {
                  'invite_code': code,
                });
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                await _load();
                if (mounted) showSnack(context, 'Вы в команде');
              } catch (e) {
                if (mounted) showSnack(context, e.toString(), isError: true);
              }
            },
            child: const Text('Войти'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ApiClient.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Команды'),
        actions: [
          TextButton(onPressed: _joinByCode, child: const Text('Код')),
          TextButton(onPressed: _createTeam, child: const Text('Создать')),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (user != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                '${user['nickname']} · ${user['presence_status']}',
                style: const TextStyle(color: kMuted, fontSize: 13),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _teams.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              const SizedBox(height: 72),
                              const Center(child: Text('Команд пока нет')),
                              const SizedBox(height: 8),
                              Center(
                                child: TextButton(
                                  onPressed: _joinByCode,
                                  child: const Text('Войти по коду'),
                                ),
                              ),
                            ],
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.only(bottom: 16),
                            itemCount: _teams.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1, indent: 16),
                            itemBuilder: (context, i) {
                              final team = _teams[i] as Map<String, dynamic>;
                              final role =
                                  team['role']?.toString() ?? 'участник';
                              final desc =
                                  team['description']?.toString() ?? '';
                              final name = team['name']?.toString() ?? '';
                              return InkWell(
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute<void>(
                                      builder: (_) => WorkspaceScreen(
                                        teamId: team['team_id'] as int,
                                        initialTeamName: name,
                                        myRole: role,
                                      ),
                                    ),
                                  );
                                  _load();
                                },
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    12,
                                    12,
                                    12,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              name,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            if (desc.isNotEmpty) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                desc,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: kMuted,
                                                  fontSize: 13,
                                                  height: 1.3,
                                                ),
                                              ),
                                            ],
                                            const SizedBox(height: 4),
                                            Text(
                                              role,
                                              style: const TextStyle(
                                                color: kMuted,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(
                                        Icons.chevron_right,
                                        size: 18,
                                        color: kMuted,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}
