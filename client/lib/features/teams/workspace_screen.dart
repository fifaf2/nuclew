import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../data/api_client.dart';
import '../../ui/snack.dart';
import '../../ui/user_avatar.dart';
import '../tasks/task_screen.dart';

class WorkspaceScreen extends StatefulWidget {
  final int teamId;
  final String initialTeamName;
  final String myRole;

  const WorkspaceScreen({
    super.key,
    required this.teamId,
    required this.initialTeamName,
    required this.myRole,
  });

  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late String _teamName;
  String? _teamDescription;

  List<dynamic> _tasks = [];
  List<dynamic> _members = [];
  List<dynamic> _statusReport = [];
  List<dynamic> _activityReport = [];

  String? _statusFilter;
  bool _includeArchived = false;
  bool _loadingTasks = true;
  bool _loadingMembers = true;
  bool _loadingReports = true;

  bool get _isOwner => widget.myRole == 'владелец команды';

  // Гость читает базу, но задачи не создаёт и людей не трогает.
  bool get _isGuest => widget.myRole == 'гость';

  static const _statuses = [
    'свободна',
    'в работе',
    'на доработке',
    'завершена',
  ];

  @override
  void initState() {
    super.initState();
    _teamName = widget.initialTeamName;
    _tabs = TabController(length: 3, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadTeam(),
      _loadTasks(),
      _loadMembers(),
      _loadReports(),
    ]);
  }

  Future<void> _loadTeam() async {
    try {
      final info = await ApiClient.instance.get(
        '/api/v1/teams/${widget.teamId}',
      );
      if (!mounted) return;
      setState(() {
        _teamName = info['name']?.toString() ?? _teamName;
        _teamDescription = info['description']?.toString();
      });
    } catch (_) {
      // Имя уже пришло из списка команд.
      return;
    }
  }

  Future<void> _loadTasks() async {
    if (!_loadingTasks && mounted) setState(() => _loadingTasks = true);
    try {
      final data = await ApiClient.instance.get(
        '/api/v1/teams/${widget.teamId}/tasks',
        {
          'status': _statusFilter,
          'include_archived': _includeArchived.toString(),
        },
      );
      if (!mounted) return;
      setState(() => _tasks = data as List<dynamic>);
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _loadingTasks = false);
    }
  }

  Future<void> _loadMembers() async {
    if (!_loadingMembers && mounted) setState(() => _loadingMembers = true);
    try {
      final data = await ApiClient.instance.get(
        '/api/v1/teams/${widget.teamId}/members',
      );
      if (!mounted) return;
      setState(() => _members = data as List<dynamic>);
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _loadingMembers = false);
    }
  }

  Future<void> _loadReports() async {
    if (!_loadingReports && mounted) setState(() => _loadingReports = true);
    try {
      final statuses = await ApiClient.instance.get(
        '/api/v1/teams/${widget.teamId}/reports/task-statuses',
      );
      var activity = <dynamic>[];
      if (_isOwner) {
        activity = await ApiClient.instance.get(
          '/api/v1/teams/${widget.teamId}/reports/activity',
        ) as List<dynamic>;
      }
      if (!mounted) return;
      setState(() {
        _statusReport = statuses as List<dynamic>;
        _activityReport = activity;
      });
    } catch (_) {
      return;
    } finally {
      if (mounted) setState(() => _loadingReports = false);
    }
  }

  Future<void> _createTask() async {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Новая задача'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Название'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentCtrl,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Текст',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () async {
              final title = titleCtrl.text.trim();
              if (title.isEmpty) {
                showSnack(context, 'Нужно название', isError: true);
                return;
              }
              try {
                await ApiClient.instance.post(
                  '/api/v1/teams/${widget.teamId}/tasks',
                  {'title': title, 'content': contentCtrl.text},
                );
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                await _loadTasks();
                await _loadReports();
                if (mounted) showSnack(context, 'Задача создана');
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

  Future<void> _editTeam() async {
    final nameCtrl = TextEditingController(text: _teamName);
    final descCtrl = TextEditingController(text: _teamDescription ?? '');
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('О команде'),
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
              try {
                await ApiClient.instance.patch(
                  '/api/v1/teams/${widget.teamId}',
                  {
                    'name': nameCtrl.text.trim(),
                    'description': descCtrl.text.trim(),
                  },
                );
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                await _loadTeam();
                if (mounted) showSnack(context, 'Сохранили');
              } catch (e) {
                if (mounted) showSnack(context, e.toString(), isError: true);
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  Future<void> _invites() async {
    final daysCtrl = TextEditingController(text: '7');
    final revokeCtrl = TextEditingController();
    Map<String, dynamic>? created;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => AlertDialog(
          title: const Text('Приглашения'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: daysCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Срок, дней'),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () async {
                    try {
                      final days = int.tryParse(daysCtrl.text) ?? 7;
                      final res = await ApiClient.instance.post(
                        '/api/v1/teams/${widget.teamId}/invitations',
                        {'expires_in_days': days},
                      );
                      setModal(() => created = res as Map<String, dynamic>);
                    } catch (e) {
                      if (mounted) {
                        showSnack(context, e.toString(), isError: true);
                      }
                    }
                  },
                  child: const Text('Получить код'),
                ),
                if (created != null) ...[
                  const SizedBox(height: 12),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: kPaper,
                      border: Border.all(color: kLine),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Номер ${created!['invitation_id']}',
                            style: const TextStyle(color: kMuted, fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          SelectableText(
                            created!['invite_code'].toString(),
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(
                                  text: created!['invite_code'].toString(),
                                ),
                              );
                              showSnack(context, 'Код скопирован');
                            },
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('Скопировать'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: revokeCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Номер, чтобы отозвать',
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () async {
                      final id = int.tryParse(revokeCtrl.text.trim());
                      if (id == null) return;
                      try {
                        await ApiClient.instance.delete(
                          '/api/v1/invitations/$id',
                        );
                        revokeCtrl.clear();
                        if (mounted) showSnack(context, 'Приглашение отозвано');
                      } catch (e) {
                        if (mounted) {
                          showSnack(context, e.toString(), isError: true);
                        }
                      }
                    },
                    style: TextButton.styleFrom(foregroundColor: kBad),
                    child: const Text('Отозвать'),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Закрыть'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _unlock(int taskId) async {
    try {
      await ApiClient.instance.post('/api/v1/tasks/$taskId/unlock');
      await _loadTasks();
      if (mounted) showSnack(context, 'Блокировку сняли');
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), isError: true);
    }
  }

  Future<void> _changeMember(int userId, String action) async {
    try {
      if (action == 'kick') {
        await ApiClient.instance.delete(
          '/api/v1/teams/${widget.teamId}/members/$userId',
        );
        if (mounted) showSnack(context, 'Исключили из команды');
      } else {
        await ApiClient.instance.patch(
          '/api/v1/teams/${widget.teamId}/members/$userId',
          {'role': action},
        );
        if (mounted) showSnack(context, 'Роль: $action');
      }
      await _loadMembers();
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _teamName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: kInk,
              ),
            ),
            Text(
              _isGuest ? 'только чтение' : widget.myRole,
              style: const TextStyle(
                fontSize: 12,
                color: kMuted,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            onPressed: _loadAll,
            icon: const Icon(Icons.refresh),
          ),
          if (_isOwner)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'invite') _invites();
                if (value == 'edit') _editTeam();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'invite', child: Text('Приглашения')),
                PopupMenuItem(value: 'edit', child: Text('О команде')),
              ],
            ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Задачи'),
            Tab(text: 'Люди'),
            Tab(text: 'Сводка'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [_tasksTab(), _membersTab(), _reportsTab()],
      ),
    );
  }

  Widget _tasksTab() {
    return Column(
      children: [
        SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: [
              _Filter(
                label: 'все',
                on: _statusFilter == null,
                onTap: () {
                  setState(() => _statusFilter = null);
                  _loadTasks();
                },
              ),
              for (final status in _statuses)
                _Filter(
                  label: status,
                  on: _statusFilter == status,
                  onTap: () {
                    setState(() {
                      _statusFilter = _statusFilter == status ? null : status;
                    });
                    _loadTasks();
                  },
                ),
              _Filter(
                label: 'архив',
                on: _includeArchived,
                onTap: () {
                  setState(() => _includeArchived = !_includeArchived);
                  _loadTasks();
                },
              ),
              if (_isOwner)
                TextButton(onPressed: _createTask, child: const Text('Новая')),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _loadingTasks
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadTasks,
                  child: _tasks.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 64),
                            Center(
                              child: Text(
                                'Пусто',
                                style: TextStyle(color: kMuted),
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: _tasks.length,
                          separatorBuilder: (_, _) =>
                              const Divider(height: 1, indent: 16),
                          itemBuilder: (context, i) {
                            final task = _tasks[i] as Map<String, dynamic>;
                            final status = task['status']?.toString() ?? '';
                            // Бэкенд шлёт is_archived и как 0/1, и как bool.
                            final archived =
                                task['is_archived'] == 1 ||
                                task['is_archived'] == true;
                            final id = task['task_id'] as int;
                            final assignee = task['assignee']?.toString();
                            return InkWell(
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) => TaskScreen(
                                      taskId: id,
                                      myRole: widget.myRole,
                                    ),
                                  ),
                                );
                                _loadTasks();
                                _loadReports();
                              },
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  10,
                                  12,
                                  8,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            task['title']?.toString() ?? '',
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              height: 1.25,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          status,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: taskStatusColor(status),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      [
                                        '#$id',
                                        if (assignee != null &&
                                            assignee.isNotEmpty)
                                          assignee,
                                        if (archived) 'в архиве',
                                      ].join(' · '),
                                      style: const TextStyle(
                                        color: kMuted,
                                        fontSize: 12,
                                      ),
                                    ),
                                    if (_isOwner && status == 'в работе')
                                      TextButton(
                                        // «в работе» висит на исполнителе, пока её не снимут.
                                        onPressed: () => _unlock(id),
                                        style: TextButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                          minimumSize: Size.zero,
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                          foregroundColor: const Color(
                                            0xFF8A5A12,
                                          ),
                                        ),
                                        child: const Text('Снять блокировку'),
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
    );
  }

  Widget _membersTab() {
    if (_loadingMembers && _members.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: _loadMembers,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _members.length,
        separatorBuilder: (_, _) => const Divider(height: 1, indent: 16),
        itemBuilder: (context, i) {
          final member = _members[i] as Map<String, dynamic>;
          final role = member['role']?.toString() ?? 'участник';
          final presence = member['presence_status']?.toString() ?? 'на месте';
          final nickname = member['nickname']?.toString() ?? '';
          final isOwner = role == 'владелец команды';
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 4, 10),
            child: Row(
              children: [
                UserAvatar(
                  nickname: nickname,
                  avatarUrl: member['avatar_url']?.toString(),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              nickname,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: presenceColor(presence),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$role · $presence',
                        style: const TextStyle(color: kMuted, fontSize: 12),
                      ),
                      Text(
                        member['email']?.toString() ?? '',
                        style: const TextStyle(color: kMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (_isOwner && !isOwner)
                  PopupMenuButton<String>(
                    onSelected: (action) =>
                        _changeMember(member['user_id'] as int, action),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'участник', child: Text('Участник')),
                      PopupMenuItem(value: 'гость', child: Text('Гость')),
                      PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'kick',
                        child: Text('Исключить', style: TextStyle(color: kBad)),
                      ),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _reportsTab() {
    if (_loadingReports && _statusReport.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: _loadReports,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          const Text(
            'Статусы',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          const SizedBox(height: 8),
          for (final row in _statusReport)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      row['status']?.toString() ?? '',
                      style: TextStyle(
                        color: taskStatusColor(row['status']?.toString() ?? ''),
                      ),
                    ),
                  ),
                  Text(
                    '${row['task_count'] ?? 0}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 22),
          const Text(
            'Кто правил',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          const SizedBox(height: 8),
          if (!_isOwner)
            const Text(
              'Подробности по людям видит владелец.',
              style: TextStyle(color: kMuted, height: 1.35),
            )
          else if (_activityReport.isEmpty)
            const Text('Пока тихо', style: TextStyle(color: kMuted))
          else
            for (final row in _activityReport)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row['nickname']?.toString() ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'правок ${row['changes_count']} · комментариев ${row['comments_count']}',
                      style: const TextStyle(color: kMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _Filter extends StatelessWidget {
  final String label;
  final bool on;
  final VoidCallback onTap;

  const _Filter({required this.label, required this.on, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: on ? kAccent : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: on ? kInk : kMuted,
              fontWeight: on ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}
