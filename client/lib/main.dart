import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const NuclewApp());
}

class NuclewApp extends StatelessWidget {
  const NuclewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nuclew — База знаний и Задачи',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF3B5BDB),
        brightness: Brightness.dark,
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
        ),
      ),
      home: const RootGate(),
    );
  }
}

// ============================================================================
// API КЛИЕНТ (Взаимодействие с FastAPI api.py)
// ============================================================================

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

class ApiClient {
  static final ApiClient instance = ApiClient._();
  ApiClient._();

  String baseUrl = 'http://10.0.2.2:8000';
  String? token;
  Map<String, dynamic>? currentUser;
  bool isSupportUser = false;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json; charset=utf-8',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  Uri _uri(String path, [Map<String, String?>? query]) {
    final cleanQuery = <String, String>{};
    if (query != null) {
      query.forEach((k, v) {
        if (v != null && v.isNotEmpty) cleanQuery[k] = v;
      });
    }
    return Uri.parse('$baseUrl$path').replace(
      queryParameters: cleanQuery.isEmpty ? null : cleanQuery,
    );
  }

  dynamic _handleResponse(http.Response res) {
    if (res.statusCode == 204) return null;
    final text = utf8.decode(res.bodyBytes);
    dynamic decoded;
    try {
      decoded = text.isNotEmpty ? jsonDecode(text) : null;
    } catch (_) {
      decoded = text;
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return decoded;
    }

    String errorMsg = 'Ошибка запроса (${res.statusCode})';
    if (decoded is Map && decoded['detail'] != null) {
      final detail = decoded['detail'];
      if (detail is String) {
        errorMsg = detail;
      } else if (detail is List && detail.isNotEmpty) {
        errorMsg = detail.map((e) => e['msg'] ?? e.toString()).join('; ');
      }
    }
    throw ApiException(res.statusCode, errorMsg);
  }

  Future<dynamic> get(String path, [Map<String, String?>? query]) async {
    final res = await http.get(_uri(path, query), headers: _headers);
    return _handleResponse(res);
  }

  Future<String> getRawText(String path) async {
    final res = await http.get(_uri(path), headers: _headers);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return utf8.decode(res.bodyBytes);
    }
    _handleResponse(res);
    return '';
  }

  Future<dynamic> post(String path, [Map<String, dynamic>? body]) async {
    final res = await http.post(
      _uri(path),
      headers: _headers,
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(res);
  }

  Future<dynamic> patch(String path, [Map<String, dynamic>? body]) async {
    final res = await http.patch(
      _uri(path),
      headers: _headers,
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(res);
  }

  Future<void> delete(String path) async {
    final res = await http.delete(_uri(path), headers: _headers);
    _handleResponse(res);
  }

  Future<void> refreshProfile() async {
    currentUser = await get('/api/v1/users/me') as Map<String, dynamic>;
    try {
      await get('/api/v1/support/requests', {'limit': '1'});
      isSupportUser = true;
    } catch (_) {
      isSupportUser = false;
    }
  }
}

void showSnack(BuildContext context, String message, {bool isError = false}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.redAccent.shade700 : null,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

class UserAvatar extends StatelessWidget {
  final String nickname;
  final String? avatarUrl;
  final double radius;

  const UserAvatar({
    super.key,
    required this.nickname,
    this.avatarUrl,
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    final cleanUrl = avatarUrl?.trim() ?? '';
    final initial = nickname.trim().isNotEmpty ? nickname.trim()[0].toUpperCase() : 'U';

    if (cleanUrl.isEmpty) {
      return CircleAvatar(
        radius: radius,
        child: Text(
          initial,
          style: TextStyle(fontSize: radius * 0.8, fontWeight: FontWeight.bold),
        ),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.white10,
      child: ClipOval(
        child: Image.network(
          cleanUrl,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Text(
            initial,
            style: TextStyle(fontSize: radius * 0.8, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// ROOT GATE (Переключатель Авторизация / Главный экран)
// ============================================================================

class RootGate extends StatefulWidget {
  const RootGate({super.key});

  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> {
  bool _authenticated = false;

  void _onLoginSuccess() {
    setState(() => _authenticated = true);
  }

  void _onLogout() {
    ApiClient.instance.token = null;
    ApiClient.instance.currentUser = null;
    setState(() => _authenticated = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_authenticated) {
      return AuthScreen(onLoginSuccess: _onLoginSuccess);
    }
    return MainShell(onLogout: _onLogout);
  }
}

// ============================================================================
// ЭКРАН АВТОРИЗАЦИИ И РЕГИСТРАЦИИ
// ============================================================================

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

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      final api = ApiClient.instance;
      Map<String, dynamic> res;
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Адрес сервера Nuclew API'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                labelText: 'Base URL',
                hintText: 'http://127.0.0.1:8000',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  label: const Text('Localhost (Linux/Web)'),
                  onPressed: () => ctrl.text = 'http://127.0.0.1:8000',
                ),
                ActionChip(
                  label: const Text('Android Эмулятор'),
                  onPressed: () => ctrl.text = 'http://10.0.2.2:8000',
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

  void _showForgotPassInfo() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Сброс пароля'),
        content: const Text(
          'В соответствии с регламентом безопасности сброс пароля выполняется '
              'специалистом технической поддержки по обращению пользователя.',
        ),
        actions: [
          FilledButton(
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
      appBar: AppBar(
        title: const Text('ИС «База знаний и Задачи»'),
        actions: [
          IconButton(
            tooltip: 'Настройки сервера',
            icon: const Icon(Icons.dns_outlined),
            onPressed: _openServerDialog,
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _isLogin ? 'Вход в систему' : 'Регистрация участника',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isLogin
                          ? 'Введите псевдоним или E-mail для доступа к рабочим пространствам команд'
                          : 'Укажите уникальный псевдоним, почту и пароль (не менее 8 символов)',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _loginCtrl,
                      decoration: InputDecoration(
                        labelText: _isLogin ? 'E-mail / Псевдоним' : 'Псевдоним (nickname)',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    if (!_isLogin) ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'E-mail',
                          prefixIcon: Icon(Icons.alternate_email),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Пароль',
                        prefixIcon: Icon(Icons.lock_outline),
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _loading
                          ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : Text(_isLogin ? 'Войти' : 'Зарегистрироваться'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () => setState(() => _isLogin = !_isLogin),
                          child: Text(_isLogin ? 'Регистрация' : 'Уже есть аккаунт'),
                        ),
                        if (_isLogin)
                          TextButton(
                            onPressed: _showForgotPassInfo,
                            child: const Text('Забыли пароль?'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// ГЛАВНАЯ ОБОЛОЧКА (Навигация: Команды, Уведомления, Профиль, АРМ ТП)
// ============================================================================

class MainShell extends StatefulWidget {
  final VoidCallback onLogout;
  const MainShell({super.key, required this.onLogout});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final isSupport = ApiClient.instance.isSupportUser;
    final screens = <Widget>[
      const TeamsDirectoryScreen(),
      const NotificationsAndSupportScreen(),
      ProfileScreen(
        onLogout: widget.onLogout,
        onProfileUpdated: () => setState(() {}),
      ),
      if (isSupport) const AdminSupportArmScreen(),
    ];

    final safeIndex = _index >= screens.length ? 0 : _index;

    return Scaffold(
      body: IndexedStack(
        index: safeIndex,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: safeIndex,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.workspaces_outline),
            selectedIcon: Icon(Icons.workspaces),
            label: 'Команды',
          ),
          const NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications),
            label: 'Уведомления',
          ),
          const NavigationDestination(
            icon: Icon(Icons.account_circle_outlined),
            selectedIcon: Icon(Icons.account_circle),
            label: 'Профиль',
          ),
          if (isSupport)
            const NavigationDestination(
              icon: Icon(Icons.admin_panel_settings_outlined),
              selectedIcon: Icon(Icons.admin_panel_settings),
              label: 'АРМ ТП',
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// РАЗДЕЛ 1: СПИСОК КОМАНД, СОЗДАНИЕ И ВСТУПЛЕНИЕ ПО ИНВАЙТ-КОДУ
// ============================================================================

class TeamsDirectoryScreen extends StatefulWidget {
  const TeamsDirectoryScreen({super.key});

  @override
  State<TeamsDirectoryScreen> createState() => _TeamsDirectoryScreenState();
}

class _TeamsDirectoryScreenState extends State<TeamsDirectoryScreen> {
  List<dynamic> _teams = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTeams();
  }

  Future<void> _loadTeams() async {
    setState(() => _loading = true);
    try {
      final data = await ApiClient.instance.get('/api/v1/teams');
      setState(() => _teams = data as List<dynamic>);
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showCreateTeamDialog() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Создать команду'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Название команды',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Описание команды',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              try {
                await ApiClient.instance.post('/api/v1/teams', {
                  'name': nameCtrl.text.trim(),
                  'description': descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                });
                if (ctx.mounted) Navigator.pop(ctx);
                _loadTeams();
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

  void _showJoinByInviteDialog() {
    final codeCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Вступить по инвайт-коду'),
        content: TextField(
          controller: codeCtrl,
          decoration: const InputDecoration(
            labelText: 'Уникальный код приглашения',
            prefixIcon: Icon(Icons.vpn_key_outlined),
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(
            onPressed: () async {
              if (codeCtrl.text.trim().isEmpty) return;
              try {
                await ApiClient.instance.post('/api/v1/invitations/join', {
                  'invite_code': codeCtrl.text.trim(),
                });
                if (ctx.mounted) Navigator.pop(ctx);
                _loadTeams();
                if (mounted) showSnack(context, 'Вы успешно присоединились к команде');
              } catch (e) {
                if (mounted) showSnack(context, e.toString(), isError: true);
              }
            },
            child: const Text('Присоединиться'),
          ),
        ],
      ),
    );
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'владелец команды':
        return Colors.amber.shade700;
      case 'участник':
        return Colors.teal.shade600;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ApiClient.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Рабочие пространства команд'),
        actions: [
          IconButton(
            tooltip: 'Вступить по инвайт-коду',
            icon: const Icon(Icons.group_add_outlined),
            onPressed: _showJoinByInviteDialog,
          ),
          IconButton(
            tooltip: 'Обновить',
            icon: const Icon(Icons.refresh),
            onPressed: _loadTeams,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateTeamDialog,
        icon: const Icon(Icons.add),
        label: const Text('Новая команда'),
      ),
      body: Column(
        children: [
          if (user != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.white.withValues(alpha: 0.03),
              child: Row(
                children: [
                  const Icon(Icons.circle, size: 10, color: Colors.greenAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Вы вошли как ${user['nickname']} • Статус: ${user['presence_status']}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _showJoinByInviteDialog,
                    icon: const Icon(Icons.key, size: 16),
                    label: const Text('Ввести инвайт-код'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _teams.isEmpty
                ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.folder_off_outlined, size: 56, color: Colors.white38),
                    const SizedBox(height: 12),
                    const Text(
                      'Вы пока не состоите ни в одной команде',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Создайте собственную команду или присоединитесь к существующей по инвайт-коду.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white60),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _showJoinByInviteDialog,
                      icon: const Icon(Icons.vpn_key_outlined),
                      label: const Text('Вступить по инвайт-коду'),
                    ),
                  ],
                ),
              ),
            )
                : RefreshIndicator(
              onRefresh: _loadTeams,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                itemCount: _teams.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (ctx, i) {
                  final team = _teams[i] as Map<String, dynamic>;
                  final role = team['role']?.toString() ?? 'участник';
                  return Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 8,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: _roleColor(role).withValues(alpha: 0.25),
                        child: Text(
                          (team['name']?.toString() ?? 'T')[0].toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(
                        team['name'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (team['description'] != null &&
                              team['description'].toString().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(team['description'].toString()),
                          ],
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: _roleColor(role).withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Роль: $role',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TeamWorkspaceScreen(
                              teamId: team['team_id'] as int,
                              initialTeamName: team['name'].toString(),
                              myRole: role,
                            ),
                          ),
                        );
                        _loadTeams();
                      },
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

// ============================================================================
// РАБОЧЕЕ ПРОСТРАНСТВО КОМАНДЫ (Задачи/База знаний, Участники, Отчеты)
// ============================================================================

class TeamWorkspaceScreen extends StatefulWidget {
  final int teamId;
  final String initialTeamName;
  final String myRole;

  const TeamWorkspaceScreen({
    super.key,
    required this.teamId,
    required this.initialTeamName,
    required this.myRole,
  });

  @override
  State<TeamWorkspaceScreen> createState() => _TeamWorkspaceScreenState();
}

class _TeamWorkspaceScreenState extends State<TeamWorkspaceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late String _teamName;
  String? _teamDescription;

  List<dynamic> _tasks = [];
  List<dynamic> _members = [];
  List<dynamic> _statusReport = [];
  List<dynamic> _activityReport = [];

  String? _selectedStatusFilter;
  bool _includeArchived = false;
  bool _loadingTasks = true;
  bool _loadingMembers = true;
  bool _loadingReports = true;

  bool get _isOwner => widget.myRole == 'владелец команды';
  bool get _isGuest => widget.myRole == 'гость';

  final List<String> _taskStatuses = const [
    'свободна',
    'в работе',
    'на доработке',
    'завершена',
  ];

  @override
  void initState() {
    super.initState();
    _teamName = widget.initialTeamName;
    _tabController = TabController(length: 3, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadTeamInfo(),
      _loadTasks(),
      _loadMembers(),
      _loadReports(),
    ]);
  }

  Future<void> _loadTeamInfo() async {
    try {
      final info = await ApiClient.instance.get('/api/v1/teams/${widget.teamId}');
      if (mounted) {
        setState(() {
          _teamName = info['name']?.toString() ?? _teamName;
          _teamDescription = info['description']?.toString();
        });
      }
    } catch (_) {}
  }

  Future<void> _loadTasks() async {
    setState(() => _loadingTasks = true);
    try {
      final data = await ApiClient.instance.get(
        '/api/v1/teams/${widget.teamId}/tasks',
        {
          'status': _selectedStatusFilter,
          'include_archived': _includeArchived.toString(),
        },
      );
      if (mounted) setState(() => _tasks = data as List<dynamic>);
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _loadingTasks = false);
    }
  }

  Future<void> _loadMembers() async {
    setState(() => _loadingMembers = true);
    try {
      final data = await ApiClient.instance.get('/api/v1/teams/${widget.teamId}/members');
      if (mounted) setState(() => _members = data as List<dynamic>);
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _loadingMembers = false);
    }
  }

  Future<void> _loadReports() async {
    setState(() => _loadingReports = true);
    try {
      final statusRep = await ApiClient.instance.get(
        '/api/v1/teams/${widget.teamId}/reports/task-statuses',
      );
      List<dynamic> actRep = [];
      if (_isOwner) {
        actRep = await ApiClient.instance.get(
          '/api/v1/teams/${widget.teamId}/reports/activity',
        ) as List<dynamic>;
      }
      if (mounted) {
        setState(() {
          _statusReport = statusRep as List<dynamic>;
          _activityReport = actRep;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingReports = false);
    }
  }

  void _showCreateTaskDialog() {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Новая задача / Документ БЗ'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Название задачи (документа)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentCtrl,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Начальное содержимое (Markdown)',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty) return;
              try {
                await ApiClient.instance.post('/api/v1/teams/${widget.teamId}/tasks', {
                  'title': titleCtrl.text.trim(),
                  'content': contentCtrl.text,
                });
                if (ctx.mounted) Navigator.pop(ctx);
                _loadTasks();
                _loadReports();
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

  void _showEditTeamDialog() {
    final nameCtrl = TextEditingController(text: _teamName);
    final descCtrl = TextEditingController(text: _teamDescription ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Редактировать инфо о команде'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Название команды',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Описание',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(
            onPressed: () async {
              try {
                await ApiClient.instance.patch('/api/v1/teams/${widget.teamId}', {
                  'name': nameCtrl.text.trim(),
                  'description': descCtrl.text.trim(),
                });
                if (ctx.mounted) Navigator.pop(ctx);
                _loadTeamInfo();
                if (mounted) showSnack(context, 'Информация о команде обновлена');
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

  void _showInvitationsModal() {
    final daysCtrl = TextEditingController(text: '7');
    final revokeIdCtrl = TextEditingController();
    Map<String, dynamic>? generatedInvite;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: const Text('Управление инвайт-кодами'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Сгенерировать новый инвайт-код:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: daysCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Срок действия (дней)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () async {
                    try {
                      final days = int.tryParse(daysCtrl.text) ?? 7;
                      final res = await ApiClient.instance.post(
                        '/api/v1/teams/${widget.teamId}/invitations',
                        {'expires_in_days': days},
                      );
                      setModalState(() => generatedInvite = res as Map<String, dynamic>);
                    } catch (e) {
                      if (mounted) showSnack(context, e.toString(), isError: true);
                    }
                  },
                  icon: const Icon(Icons.vpn_key),
                  label: const Text('Сгенерировать инвайт-код'),
                ),
                if (generatedInvite != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ID приглашения: ${generatedInvite!['invitation_id']}'),
                        const SizedBox(height: 4),
                        SelectableText(
                          'Код: ${generatedInvite!['invite_code']}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        TextButton.icon(
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(text: generatedInvite!['invite_code'].toString()),
                            );
                            showSnack(context, 'Инвайт-код скопирован в буфер обмена');
                          },
                          icon: const Icon(Icons.copy, size: 16),
                          label: const Text('Скопировать код'),
                        ),
                      ],
                    ),
                  ),
                ],
                const Divider(height: 28),
                const Text(
                  'Аннулировать инвайт по ID приглашения:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: revokeIdCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'ID приглашения (invitation_id)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final id = int.tryParse(revokeIdCtrl.text.trim());
                    if (id == null) return;
                    try {
                      await ApiClient.instance.delete('/api/v1/invitations/$id');
                      if (mounted) showSnack(context, 'Приглашение #$id отозвано');
                      revokeIdCtrl.clear();
                    } catch (e) {
                      if (mounted) showSnack(context, e.toString(), isError: true);
                    }
                  },
                  icon: const Icon(Icons.block, color: Colors.redAccent),
                  label: const Text('Аннулировать приглашение'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Закрыть')),
          ],
        ),
      ),
    );
  }

  Color _statusBadgeColor(String status) {
    switch (status) {
      case 'свободна':
        return Colors.blue;
      case 'в работе':
        return Colors.orange;
      case 'на доработке':
        return Colors.redAccent;
      case 'завершена':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_teamName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            Text(
              _isGuest
                  ? 'База знаний (Режим только чтение • Гость)'
                  : 'Ваша роль: ${widget.myRole}',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          if (_isOwner) ...[
            IconButton(
              tooltip: 'Инвайт-коды',
              icon: const Icon(Icons.vpn_key_outlined),
              onPressed: _showInvitationsModal,
            ),
            IconButton(
              tooltip: 'Редактировать инфо о команде',
              icon: const Icon(Icons.edit_outlined),
              onPressed: _showEditTeamDialog,
            ),
          ],
          IconButton(
            tooltip: 'Обновить данные',
            icon: const Icon(Icons.refresh),
            onPressed: _loadAll,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.description_outlined), text: 'Задачи и БЗ'),
            Tab(icon: Icon(Icons.people_outline), text: 'Участники'),
            Tab(icon: Icon(Icons.analytics_outlined), text: 'Сводки и Отчеты'),
          ],
        ),
      ),
      floatingActionButton: _isOwner
          ? FloatingActionButton.extended(
        onPressed: _showCreateTaskDialog,
        icon: const Icon(Icons.add_task),
        label: const Text('Создать задачу'),
      )
          : null,
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTasksTab(),
          _buildMembersTab(),
          _buildReportsTab(),
        ],
      ),
    );
  }

  Widget _buildTasksTab() {
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              FilterChip(
                label: const Text('Все статусы'),
                selected: _selectedStatusFilter == null,
                onSelected: (_) {
                  setState(() => _selectedStatusFilter = null);
                  _loadTasks();
                },
              ),
              const SizedBox(width: 8),
              ..._taskStatuses.map(
                    (st) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(st),
                    selected: _selectedStatusFilter == st,
                    onSelected: (val) {
                      setState(() => _selectedStatusFilter = val ? st : null);
                      _loadTasks();
                    },
                  ),
                ),
              ),
              FilterChip(
                label: const Text('Архивные'),
                selected: _includeArchived,
                onSelected: (val) {
                  setState(() => _includeArchived = val);
                  _loadTasks();
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: _loadingTasks
              ? const Center(child: CircularProgressIndicator())
              : _tasks.isEmpty
              ? const Center(child: Text('Задачи по выбранному фильтру не найдены'))
              : RefreshIndicator(
            onRefresh: _loadTasks,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
              itemCount: _tasks.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final t = _tasks[i] as Map<String, dynamic>;
                final st = t['status']?.toString() ?? '';
                final badgeColor = _statusBadgeColor(st);
                return Card(
                  child: ListTile(
                    title: Row(
                      children: [
                        Text(
                          '#${t['task_id']} ',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            t['title']?.toString() ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: badgeColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              st,
                              style: TextStyle(
                                fontSize: 12,
                                color: badgeColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (t['assignee'] != null)
                            Text(
                              'Исполнитель: ${t['assignee']}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          if (t['is_archived'] == 1 || t['is_archived'] == true)
                            const Text(
                              '[В АРХИВЕ]',
                              style: TextStyle(fontSize: 12, color: Colors.amber),
                            ),
                        ],
                      ),
                    ),
                    trailing: _isOwner && st == 'в работе'
                        ? IconButton(
                      tooltip: 'Принудительно снять блокировку',
                      icon: const Icon(Icons.lock_open, color: Colors.amber),
                      onPressed: () async {
                        try {
                          await ApiClient.instance.post(
                            '/api/v1/tasks/${t['task_id']}/unlock',
                          );
                          _loadTasks();
                          if (mounted) {
                            showSnack(context, 'Блокировка снята');
                          }
                        } catch (e) {
                          if (mounted) {
                            showSnack(context, e.toString(), isError: true);
                          }
                        }
                      },
                    )
                        : const Icon(Icons.chevron_right),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TaskDetailScreen(
                            taskId: t['task_id'] as int,
                            myRole: widget.myRole,
                          ),
                        ),
                      );
                      _loadTasks();
                      _loadReports();
                    },
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMembersTab() {
    if (_loadingMembers) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: _loadMembers,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _members.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (ctx, i) {
          final m = _members[i] as Map<String, dynamic>;
          final mRole = m['role']?.toString() ?? 'участник';
          final presence = m['presence_status']?.toString() ?? 'на месте';
          final isTargetOwner = mRole == 'владелец команды';

          Color presenceColor = Colors.greenAccent;
          if (presence == 'отошел') presenceColor = Colors.amber;
          if (presence == 'не беспокоить') presenceColor = Colors.redAccent;

          return Card(
            child: ListTile(
              leading: Stack(
                children: [
                  UserAvatar(
                    nickname: m['nickname']?.toString() ?? 'U',
                    avatarUrl: m['avatar_url']?.toString(),
                    radius: 20,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: presenceColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              title: Text(
                '${m['nickname']} (${m['email']})',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text('Роль: $mRole • Статус: $presence'),
              trailing: (_isOwner && !isTargetOwner)
                  ? PopupMenuButton<String>(
                onSelected: (action) async {
                  final uid = m['user_id'];
                  try {
                    if (action == 'участник' || action == 'гость') {
                      await ApiClient.instance.patch(
                        '/api/v1/teams/${widget.teamId}/members/$uid',
                        {'role': action},
                      );
                      if (mounted) {
                        showSnack(context, 'Назначена роль: $action');
                      }
                    } else if (action == 'kick') {
                      await ApiClient.instance.delete(
                        '/api/v1/teams/${widget.teamId}/members/$uid',
                      );
                      if (mounted) {
                        showSnack(context, 'Пользователь исключен из команды');
                      }
                    }
                    _loadMembers();
                  } catch (e) {
                    if (mounted) showSnack(context, e.toString(), isError: true);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'участник',
                    child: Text('Сделать участником'),
                  ),
                  PopupMenuItem(
                    value: 'гость',
                    child: Text('Перевести в роль «Гость»'),
                  ),
                  PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'kick',
                    child: Text(
                      'Исключить из команды',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ),
                ],
              )
                  : null,
            ),
          );
        },
      ),
    );
  }

  Widget _buildReportsTab() {
    if (_loadingReports) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: _loadReports,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Сводный отчет по статусам задач команды',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: _statusReport.map((row) {
                  final st = row['status']?.toString() ?? '';
                  final cnt = row['task_count'] ?? 0;
                  return ListTile(
                    dense: true,
                    leading: Icon(Icons.circle, size: 12, color: _statusBadgeColor(st)),
                    title: Text(st.toUpperCase()),
                    trailing: Text(
                      '$cnt шт.',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (_isOwner) ...[
            Text(
              'Сводка активности участников команды (для владельца)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: _activityReport.map((row) {
                    return ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: Text(row['nickname']?.toString() ?? ''),
                      subtitle: Text(
                        'Внесено ревизий (правок): ${row['changes_count']} • Комментариев: ${row['comments_count']}',
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ] else
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Детальная сводка активности по участникам доступна владельцу команды.',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// ЭКРАН ЗАДАЧИ / ДОКУМЕНТА БАЗЫ ЗНАНИЙ
// (Редактор Markdown, Построчные замечания, История версий Diff, Комментарии)
// ============================================================================

class TaskDetailScreen extends StatefulWidget {
  final int taskId;
  final String myRole;

  const TaskDetailScreen({
    super.key,
    required this.taskId,
    required this.myRole,
  });

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  Map<String, dynamic>? _task;
  List<dynamic> _changes = [];
  List<dynamic> _remarks = [];
  List<dynamic> _comments = [];

  bool _loading = true;
  bool _editMode = false;

  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();

  bool get _isOwner => widget.myRole == 'владелец команды';
  bool get _isGuest => widget.myRole == 'гость';

  int? get _myUserId => ApiClient.instance.currentUser?['user_id'] as int?;
  bool get _isAssignedToMe =>
      _task != null && _task!['assignee_user_id'] != null && _task!['assignee_user_id'] == _myUserId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadTaskBundle();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTaskBundle() async {
    setState(() => _loading = true);
    try {
      final api = ApiClient.instance;
      final results = await Future.wait([
        api.get('/api/v1/tasks/${widget.taskId}'),
        api.get('/api/v1/tasks/${widget.taskId}/remarks'),
        api.get('/api/v1/tasks/${widget.taskId}/changes'),
        api.get('/api/v1/tasks/${widget.taskId}/comments'),
      ]);
      if (mounted) {
        setState(() {
          _task = results[0] as Map<String, dynamic>;
          _remarks = results[1] as List<dynamic>;
          _changes = results[2] as List<dynamic>;
          _comments = results[3] as List<dynamic>;
          _titleCtrl.text = _task!['title']?.toString() ?? '';
          _contentCtrl.text = _task!['content']?.toString() ?? '';
        });
      }
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _claimTask() async {
    try {
      await ApiClient.instance.post('/api/v1/tasks/${widget.taskId}/claim');
      await _loadTaskBundle();
      if (mounted) showSnack(context, 'Задача переведена в статус «в работе»');
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), isError: true);
    }
  }

  Future<void> _saveTaskChanges() async {
    try {
      await ApiClient.instance.patch('/api/v1/tasks/${widget.taskId}', {
        'title': _titleCtrl.text.trim(),
        'content': _contentCtrl.text,
      });
      setState(() => _editMode = false);
      await _loadTaskBundle();
      if (mounted) showSnack(context, 'Изменения синхронизированы на сервер');
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), isError: true);
    }
  }

  Future<void> _completeTask() async {
    try {
      if (_editMode) {
        await _saveTaskChanges();
      }
      await ApiClient.instance.post('/api/v1/tasks/${widget.taskId}/complete');
      await _loadTaskBundle();
      if (mounted) showSnack(context, 'Задача успешно завершена');
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), isError: true);
    }
  }

  Future<void> _unlockTask() async {
    try {
      await ApiClient.instance.post('/api/v1/tasks/${widget.taskId}/unlock');
      await _loadTaskBundle();
      if (mounted) showSnack(context, 'Блокировка со статуса «в работе» снята');
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), isError: true);
    }
  }

  Future<void> _archiveTask() async {
    try {
      await ApiClient.instance.post('/api/v1/tasks/${widget.taskId}/archive');
      if (mounted) {
        showSnack(context, 'Задача переведена в архив');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), isError: true);
    }
  }

  Future<void> _exportMarkdown() async {
    try {
      final md = await ApiClient.instance.getRawText('/api/v1/tasks/${widget.taskId}/export');
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Экспорт документа (.md)'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: SelectableText(
                md,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Закрыть')),
            FilledButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: md));
                Navigator.pop(ctx);
                showSnack(context, 'Markdown-документ скопирован в буфер обмена');
              },
              icon: const Icon(Icons.copy),
              label: const Text('Скопировать .md'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), isError: true);
    }
  }

  void _showAddRemarkDialog({String? preselectedFragment, int? preselectedChangeId}) {
    final fragCtrl = TextEditingController(text: preselectedFragment ?? '');
    final textCtrl = TextEditingController();
    int? selectedChangeId = preselectedChangeId ??
        (_changes.isNotEmpty ? (_changes.first['change_id'] as int?) : null);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: const Text('Отправить замечание на доработку'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: fragCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Выделенный фрагмент (номер строки или блок) *',
                    hintText: 'Например: Строка 14: ## API спецификация',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                if (_changes.isNotEmpty)
                  DropdownButtonFormField<int?>(
                    initialValue: selectedChangeId,
                    decoration: const InputDecoration(
                      labelText: 'Привязка к версии (change_id)',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Без привязки к ревизии'),
                      ),
                      ..._changes.map(
                            (c) => DropdownMenuItem<int?>(
                          value: c['change_id'] as int,
                          child: Text(
                            'Ревизия #${c['change_id']} (${c['author']} — ${c['change_date']})',
                          ),
                        ),
                      ),
                    ],
                    onChanged: (val) => setModalState(() => selectedChangeId = val),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: textCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Текст замечания (описание доработки) *',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
            FilledButton(
              onPressed: () async {
                if (fragCtrl.text.trim().isEmpty || textCtrl.text.trim().isEmpty) {
                  showSnack(
                    context,
                    'Необходимо выделить конкретную строку/фрагмент и указать текст замечания',
                    isError: true,
                  );
                  return;
                }
                try {
                  await ApiClient.instance.post('/api/v1/tasks/${widget.taskId}/remarks', {
                    'fragment_identifier': fragCtrl.text.trim(),
                    'text': textCtrl.text.trim(),
                    'change_id': selectedChangeId,
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  await _loadTaskBundle();
                  if (mounted) {
                    showSnack(context, 'Замечание добавлено, задача переведена «на доработке»');
                  }
                } catch (e) {
                  if (mounted) showSnack(context, e.toString(), isError: true);
                }
              },
              child: const Text('Отправить на доработку'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _task == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Задача #${widget.taskId}')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final status = _task!['status']?.toString() ?? '';
    final canClaim = !_isGuest &&
        (status == 'свободна' ||
            (status == 'на доработке' &&
                (_task!['assignee_user_id'] == null || _isAssignedToMe)));

    return Scaffold(
      appBar: AppBar(
        title: Text('Task #${widget.taskId}: ${_task!['title']}'),
        actions: [
          IconButton(
            tooltip: 'Экспорт документа (.md)',
            icon: const Icon(Icons.download_outlined),
            onPressed: _exportMarkdown,
          ),
          if (_isOwner) ...[
            if (status == 'в работе')
              IconButton(
                tooltip: 'Снять зависшую блокировку',
                icon: const Icon(Icons.lock_open, color: Colors.amber),
                onPressed: _unlockTask,
              ),
            IconButton(
              tooltip: 'Перевести задачу в архив',
              icon: const Icon(Icons.archive_outlined),
              onPressed: _archiveTask,
            ),
          ],
          IconButton(
            tooltip: 'Обновить',
            icon: const Icon(Icons.refresh),
            onPressed: _loadTaskBundle,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            const Tab(icon: Icon(Icons.article_outlined), text: 'Документ (Markdown)'),
            Tab(
              icon: const Icon(Icons.rate_review_outlined),
              text: 'Замечания (${_remarks.length})',
            ),
            Tab(
              icon: const Icon(Icons.history_edu_outlined),
              text: 'История версий (${_changes.length})',
            ),
            Tab(
              icon: const Icon(Icons.forum_outlined),
              text: 'Комментарии (${_comments.length})',
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildTaskActionToolbar(status, canClaim),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildMarkdownDocumentTab(),
                _buildRemarksTab(),
                _buildChangesDiffTab(),
                _buildCommentsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskActionToolbar(String status, bool canClaim) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.white.withValues(alpha: 0.04),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Chip(
                label: Text('Статус: $status'),
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 8),
              if (_isGuest)
                const Text(
                  'Режим чтения (Гость)',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
            ],
          ),
          if (!_isGuest)
            Wrap(
              spacing: 8,
              children: [
                if (canClaim)
                  FilledButton.icon(
                    onPressed: _claimTask,
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('Взять в работу'),
                  ),
                if (_isAssignedToMe && status == 'в работе') ...[
                  OutlinedButton.icon(
                    onPressed: () {
                      if (_editMode) {
                        _saveTaskChanges();
                      } else {
                        setState(() => _editMode = true);
                      }
                    },
                    icon: Icon(_editMode ? Icons.cloud_upload : Icons.edit, size: 18),
                    label: Text(_editMode ? 'Синхронизировать на сервер' : 'Редактировать'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _completeTask,
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Завершить задачу'),
                  ),
                ],
                OutlinedButton.icon(
                  onPressed: () => _showAddRemarkDialog(),
                  icon: const Icon(Icons.flag_outlined, size: 18),
                  label: const Text('Замечание к строке'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildMarkdownDocumentTab() {
    if (_editMode && _isAssignedToMe) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Заголовок задачи / документа',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _contentCtrl,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                decoration: const InputDecoration(
                  labelText: 'Содержимое (Markdown)',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final rawContent = (_task!['content']?.toString() ?? '');
    final lines = rawContent.isEmpty ? <String>['(Документ пока пуст)'] : rawContent.split('\n');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (!_isGuest)
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text(
              'Подсказка: нажмите на любую строку документа, чтобы выделить её и отправить автору замечание на доработку.',
              style: TextStyle(fontSize: 12, color: Colors.white60),
            ),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: List.generate(lines.length, (idx) {
                final lineNum = idx + 1;
                final lineText = lines[idx];
                final isHeader = lineText.trimLeft().startsWith('#');
                return InkWell(
                  onTap: _isGuest
                      ? null
                      : () => _showAddRemarkDialog(
                    preselectedFragment: 'Строка $lineNum: $lineText',
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 40,
                          child: Text(
                            '$lineNum',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              color: Colors.white38,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            lineText.isEmpty ? ' ' : lineText,
                            style: TextStyle(
                              fontFamily: isHeader ? null : 'monospace',
                              fontSize: isHeader ? 16 : 14,
                              fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
                              color: isHeader ? Colors.lightBlueAccent : Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRemarksTab() {
    if (_remarks.isEmpty) {
      return const Center(child: Text('Лист замечаний и доработок пуст'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _remarks.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final r = _remarks[i] as Map<String, dynamic>;
        final isOpen = r['status'] == 'открыто';
        return Card(
          child: ListTile(
            leading: Icon(
              isOpen ? Icons.warning_amber_rounded : Icons.verified_outlined,
              color: isOpen ? Colors.orangeAccent : Colors.greenAccent,
            ),
            title: Text(
              r['fragment_identifier']?.toString() ?? '',
              style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                Text(r['text']?.toString() ?? ''),
                const SizedBox(height: 6),
                Text(
                  'Автор: ${r['author']} • Статус: ${r['status']}'
                      '${r['change_id'] != null ? ' • Ревизия #${r['change_id']}' : ''}',
                  style: const TextStyle(fontSize: 12, color: Colors.white60),
                ),
              ],
            ),
            trailing: (!_isGuest && isOpen)
                ? FilledButton.tonal(
              onPressed: () async {
                try {
                  await ApiClient.instance.patch('/api/v1/remarks/${r['remark_id']}');
                  _loadTaskBundle();
                  if (mounted) showSnack(context, 'Замечание отмечено как устраненное');
                } catch (e) {
                  if (mounted) showSnack(context, e.toString(), isError: true);
                }
              },
              child: const Text('Устранено'),
            )
                : null,
          ),
        );
      },
    );
  }

  Widget _buildChangesDiffTab() {
    if (_changes.isEmpty) {
      return const Center(child: Text('Журнал истории версий пока пуст'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _changes.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        final c = _changes[i] as Map<String, dynamic>;
        final diff = c['diff_content']?.toString() ?? '';
        final diffLines = diff.split('\n');
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Ревизия #${c['change_id']} • ${c['author']} (${c['author_role']})',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text(
                      '${c['change_date']} ${c['change_time']}',
                      style: const TextStyle(fontSize: 12, color: Colors.white60),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: diffLines.map((line) {
                      Color lineColor = Colors.white70;
                      if (line.startsWith('+') && !line.startsWith('+++')) {
                        lineColor = Colors.greenAccent;
                      } else if (line.startsWith('-') && !line.startsWith('---')) {
                        lineColor = Colors.redAccent;
                      } else if (line.startsWith('@@')) {
                        lineColor = Colors.lightBlueAccent;
                      }
                      return Text(
                        line,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: lineColor,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                if (!_isGuest)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _showAddRemarkDialog(
                        preselectedFragment: 'Ревизия #${c['change_id']}',
                        preselectedChangeId: c['change_id'] as int,
                      ),
                      icon: const Icon(Icons.flag_outlined, size: 16),
                      label: const Text('Добавить замечание к этой ревизии'),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCommentsTab() {
    return Column(
      children: [
        Expanded(
          child: _comments.isEmpty
              ? const Center(child: Text('Комментариев пока нет'))
              : ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _comments.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) {
              final cm = _comments[i] as Map<String, dynamic>;
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text((cm['author']?.toString() ?? 'U')[0].toUpperCase()),
                  ),
                  title: Text(
                    cm['author']?.toString() ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(cm['text']?.toString() ?? ''),
                      const SizedBox(height: 4),
                      Text(
                        cm['created_time']?.toString() ?? '',
                        style: const TextStyle(fontSize: 11, color: Colors.white54),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (!_isGuest)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Написать комментарий к задаче...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  icon: const Icon(Icons.send),
                  onPressed: () async {
                    if (_commentCtrl.text.trim().isEmpty) return;
                    try {
                      await ApiClient.instance.post(
                        '/api/v1/tasks/${widget.taskId}/comments',
                        {'text': _commentCtrl.text.trim()},
                      );
                      _commentCtrl.clear();
                      _loadTaskBundle();
                    } catch (e) {
                      if (mounted) showSnack(context, e.toString(), isError: true);
                    }
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ============================================================================
// РАЗДЕЛ 2: УВЕДОМЛЕНИЯ И ОБРАЩЕНИЕ В ТЕХПОДДЕРЖКУ
// ============================================================================

class NotificationsAndSupportScreen extends StatefulWidget {
  const NotificationsAndSupportScreen({super.key});

  @override
  State<NotificationsAndSupportScreen> createState() =>
      _NotificationsAndSupportScreenState();
}

class _NotificationsAndSupportScreenState extends State<NotificationsAndSupportScreen> {
  List<dynamic> _notifications = [];
  bool _unreadOnly = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _loading = true);
    try {
      final data = await ApiClient.instance.get(
        '/api/v1/users/me/notifications',
        {'unread_only': _unreadOnly.toString()},
      );
      if (mounted) setState(() => _notifications = data as List<dynamic>);
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showCreateSupportRequestModal() {
    final subjCtrl = TextEditingController();
    final textCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Новое обращение в техподдержку'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: subjCtrl,
              decoration: const InputDecoration(
                labelText: 'Тема обращения',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Описание проблемы / инцидента',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(
            onPressed: () async {
              if (subjCtrl.text.trim().isEmpty || textCtrl.text.trim().isEmpty) return;
              try {
                await ApiClient.instance.post('/api/v1/support/requests', {
                  'subject': subjCtrl.text.trim(),
                  'text': textCtrl.text.trim(),
                });
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) showSnack(context, 'Обращение отправлено специалистам ТП');
              } catch (e) {
                if (mounted) showSnack(context, e.toString(), isError: true);
              }
            },
            child: const Text('Отправить'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Центр уведомлений'),
        actions: [
          FilterChip(
            label: const Text('Только непрочитанные'),
            selected: _unreadOnly,
            onSelected: (v) {
              setState(() => _unreadOnly = v);
              _loadNotifications();
            },
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadNotifications,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateSupportRequestModal,
        icon: const Icon(Icons.support_agent),
        label: const Text('Написать в ТП'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
          ? const Center(child: Text('Уведомлений нет'))
          : RefreshIndicator(
        onRefresh: _loadNotifications,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
          itemCount: _notifications.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (ctx, i) {
            final n = _notifications[i] as Map<String, dynamic>;
            final isUnread = n['status'] == 'не прочитано';
            return Card(
              child: ListTile(
                leading: Icon(
                  isUnread
                      ? Icons.mark_email_unread_outlined
                      : Icons.mark_email_read_outlined,
                  color: isUnread ? Colors.amberAccent : Colors.white54,
                ),
                title: Text(
                  n['text']?.toString() ?? '',
                  style: TextStyle(
                    fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                subtitle: Text('${n['sent_time']} • Статус: ${n['status']}'),
                trailing: IconButton(
                  tooltip: isUnread ? 'Отметить прочитанным' : 'Отметить непрочитанным',
                  icon: Icon(isUnread ? Icons.done : Icons.replay),
                  onPressed: () async {
                    try {
                      await ApiClient.instance.patch(
                        '/api/v1/notifications/${n['notification_id']}',
                        {'read': isUnread},
                      );
                      _loadNotifications();
                    } catch (e) {
                      if (mounted) showSnack(context, e.toString(), isError: true);
                    }
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ============================================================================
// РАЗДЕЛ 3: ЛИЧНЫЙ КАБИНЕТ (ПРОФИЛЬ И СТАТУС ПРИСУТСТВИЯ)
// ============================================================================

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

  final List<String> _presenceOptions = const [
    'на месте',
    'отошел',
    'не беспокоить',
  ];

  @override
  void initState() {
    super.initState();
    _syncFields();
  }

  void _syncFields() {
    final u = ApiClient.instance.currentUser;
    if (u != null) {
      _nicknameCtrl.text = u['nickname']?.toString() ?? '';
      _avatarCtrl.text = u['avatar_url']?.toString() ?? '';
      final p = u['presence_status']?.toString() ?? 'на месте';
      if (_presenceOptions.contains(p)) {
        _presence = p;
      }
    }
  }

  Future<void> _updatePresence(String newStatus) async {
    try {
      await ApiClient.instance.patch('/api/v1/users/me/presence', {'status': newStatus});
      await ApiClient.instance.refreshProfile();
      setState(() => _presence = newStatus);
      widget.onProfileUpdated?.call();
      if (mounted) showSnack(context, 'Статус присутствия: $newStatus');
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), isError: true);
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _saving = true);
    try {
      final body = <String, dynamic>{
        'nickname': _nicknameCtrl.text.trim(),
        'avatar_url': _avatarCtrl.text.trim().isEmpty ? null : _avatarCtrl.text.trim(),
      };
      if (_passwordCtrl.text.isNotEmpty) {
        body['password'] = _passwordCtrl.text;
      }
      await ApiClient.instance.patch('/api/v1/users/me', body);
      await ApiClient.instance.refreshProfile();
      _passwordCtrl.clear();
      _syncFields();
      setState(() {});
      widget.onProfileUpdated?.call();
      if (mounted) showSnack(context, 'Профиль успешно обновлен');
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
      appBar: AppBar(
        title: const Text('Профиль пользователя'),
        actions: [
          IconButton(
            tooltip: 'Выйти из аккаунта',
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: widget.onLogout,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        UserAvatar(
                          nickname: user?['nickname']?.toString() ?? 'U',
                          avatarUrl: user?['avatar_url']?.toString(),
                          radius: 32,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?['nickname']?.toString() ?? '',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'ID: #${user?['user_id']} • ${user?['email']}',
                                style: const TextStyle(color: Colors.white70),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Учетная запись: ${user?['activity_status']}',
                                style: const TextStyle(fontSize: 12, color: Colors.greenAccent),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Социальный статус присутствия',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _presence,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.sensors),
                          ),
                          items: _presenceOptions
                              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) _updatePresence(v);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Редактирование профиля и безопасности',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _nicknameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Псевдоним (nickname)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _avatarCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Ссылка на аватар (прямой URL картинки)',
                            hintText: 'https://i.pravatar.cc/300',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _passwordCtrl,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Новый пароль (оставьте пустым, если не меняете)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _saving ? null : _saveProfile,
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('Сохранить изменения'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// РАЗДЕЛ 4: АРМ СПЕЦИАЛИСТА ТЕХНИЧЕСКОЙ ПОДДЕРЖКИ (АДМИНИСТРИРОВАНИЕ)
// ============================================================================

class AdminSupportArmScreen extends StatefulWidget {
  const AdminSupportArmScreen({super.key});

  @override
  State<AdminSupportArmScreen> createState() => _AdminSupportArmScreenState();
}

class _AdminSupportArmScreenState extends State<AdminSupportArmScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<dynamic> _users = [];
  List<dynamic> _teams = [];
  List<dynamic> _supportRequests = [];
  List<dynamic> _logs = [];

  String? _accessError;
  bool _loading = true;

  final _userSearchCtrl = TextEditingController();
  final _unlockTaskIdCtrl = TextEditingController();
  final _inspectTaskIdCtrl = TextEditingController();
  List<dynamic> _inspectedChanges = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAdminAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _userSearchCtrl.dispose();
    _unlockTaskIdCtrl.dispose();
    _inspectTaskIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAdminAll() async {
    setState(() {
      _loading = true;
      _accessError = null;
    });
    try {
      final api = ApiClient.instance;
      final res = await Future.wait([
        api.get('/api/v1/admin/users', {'q': _userSearchCtrl.text.trim()}),
        api.get('/api/v1/support/requests'),
        api.get('/api/v1/admin/teams'),
        api.get('/api/v1/admin/system-logs'),
      ]);
      if (mounted) {
        setState(() {
          _users = res[0] as List<dynamic>;
          _supportRequests = res[1] as List<dynamic>;
          _teams = res[2] as List<dynamic>;
          _logs = res[3] as List<dynamic>;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _accessError = e.toString());
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = ApiClient.instance.currentUser?['user_id'];
    return Scaffold(
      appBar: AppBar(
        title: const Text('АРМ Технической поддержки'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAdminAll,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.manage_accounts_outlined), text: 'Реестр пользователей'),
            Tab(icon: Icon(Icons.contact_support_outlined), text: 'Обращения в ТП'),
            Tab(icon: Icon(Icons.lock_reset_outlined), text: 'Мониторинг задач и команд'),
            Tab(icon: Icon(Icons.terminal_outlined), text: 'Системные журналы'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _accessError != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.security_outlined, size: 52, color: Colors.amber),
                  const SizedBox(height: 12),
                  Text(
                    _accessError!,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ваш user_id: $myId. Для доступа к АРМ Техподдержки запустите сервер FastAPI с переменной окружения SUPPORT_USER_IDS=$myId',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _loadAdminAll,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Проверить доступ повторно'),
                  ),
                ],
              ),
            ),
          ),
        ),
      )
          : TabBarView(
        controller: _tabController,
        children: [
          _buildAdminUsersTab(),
          _buildSupportRequestsTab(),
          _buildHungTasksAndTeamsTab(),
          _buildSystemLogsTab(),
        ],
      ),
    );
  }

  Widget _buildAdminUsersTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _userSearchCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Поиск по псевдониму или E-mail...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _loadAdminAll(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _loadAdminAll,
                child: const Text('Найти'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: _users.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) {
              final u = _users[i] as Map<String, dynamic>;
              final isActive = u['activity_status'] == 'активен';
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '#${u['user_id']} ${u['nickname']}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isActive ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              u['activity_status'],
                              style: TextStyle(
                                fontSize: 12,
                                color: isActive ? Colors.greenAccent : Colors.redAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '📧 ${u['email']} • 🟢 ${u['presence_status']}',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () async {
                              try {
                                final res = await ApiClient.instance.post(
                                  '/api/v1/admin/users/${u['user_id']}/password-reset',
                                );
                                if (!mounted) return;
                                showDialog(
                                  context: context,
                                  builder: (dCtx) => AlertDialog(
                                    title: Text('Пароль сброшен (${u['nickname']})'),
                                    content: SelectableText(
                                      'Временный пароль: ${res['temporary_password']}',
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    actions: [
                                      FilledButton(
                                        onPressed: () => Navigator.pop(dCtx),
                                        child: const Text('Готово'),
                                      ),
                                    ],
                                  ),
                                );
                              } catch (e) {
                                if (mounted) showSnack(context, e.toString(), isError: true);
                              }
                            },
                            icon: const Icon(Icons.lock_reset, size: 16),
                            label: const Text('Сброс пароля'),
                          ),
                          FilledButton.tonal(
                            onPressed: () async {
                              try {
                                await ApiClient.instance.patch(
                                  '/api/v1/admin/users/${u['user_id']}/activity',
                                  {'active': !isActive},
                                );
                                _loadAdminAll();
                              } catch (e) {
                                if (mounted) showSnack(context, e.toString(), isError: true);
                              }
                            },
                            child: Text(isActive ? 'Блокировать' : 'Разблокировать'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSupportRequestsTab() {
    if (_supportRequests.isEmpty) {
      return const Center(child: Text('Обращений в техническую поддержку нет'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _supportRequests.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final sr = _supportRequests[i] as Map<String, dynamic>;
        final processed = sr['processed_time'] != null;
        return Card(
          child: ListTile(
            leading: Icon(
              processed ? Icons.check_circle : Icons.pending_actions,
              color: processed ? Colors.greenAccent : Colors.amberAccent,
            ),
            title: Text(
              '#${sr['request_id']} ${sr['subject']}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(sr['text']?.toString() ?? ''),
                const SizedBox(height: 4),
                Text(
                  'От: ${sr['nickname']} (${sr['email']}) • Создано: ${sr['created_time']}',
                  style: const TextStyle(fontSize: 12, color: Colors.white60),
                ),
              ],
            ),
            trailing: FilledButton.tonal(
              onPressed: () async {
                try {
                  await ApiClient.instance.patch(
                    '/api/v1/support/requests/${sr['request_id']}',
                    {'processed': !processed},
                  );
                  _loadAdminAll();
                } catch (e) {
                  if (mounted) showSnack(context, e.toString(), isError: true);
                }
              },
              child: Text(processed ? 'Вернуть в работу' : 'Обработано'),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHungTasksAndTeamsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Принудительное снятие зависших блокировок с задач',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _unlockTaskIdCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Код задачи (task_id)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: () async {
                        final id = int.tryParse(_unlockTaskIdCtrl.text.trim());
                        if (id == null) return;
                        try {
                          await ApiClient.instance.post('/api/v1/admin/tasks/$id/unlock');
                          if (mounted) {
                            showSnack(context, 'Задача #$id принудительно разблокирована');
                          }
                        } catch (e) {
                          if (mounted) showSnack(context, e.toString(), isError: true);
                        }
                      },
                      icon: const Icon(Icons.lock_open),
                      label: const Text('Разблокировать'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Диагностика истории фиксаций по задаче',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _inspectTaskIdCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Код задачи (task_id)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final id = int.tryParse(_inspectTaskIdCtrl.text.trim());
                        if (id == null) return;
                        try {
                          final list = await ApiClient.instance.get(
                            '/api/v1/admin/tasks/$id/changes',
                          );
                          setState(() => _inspectedChanges = list as List<dynamic>);
                        } catch (e) {
                          if (mounted) showSnack(context, e.toString(), isError: true);
                        }
                      },
                      icon: const Icon(Icons.history),
                      label: const Text('Загрузить историю'),
                    ),
                  ],
                ),
                if (_inspectedChanges.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ..._inspectedChanges.map(
                        (c) => ListTile(
                      dense: true,
                      title: Text(
                        'Ревизия #${c['change_id']} — ${c['author']} (${c['author_role']})',
                      ),
                      subtitle: Text(
                        c['diff_content']?.toString() ?? '',
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Реестр всех команд в системе',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        ..._teams.map(
              (t) => Card(
            child: ListTile(
              title: Text(
                'Команда #${t['team_id']}: ${t['name']}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'Владелец: ${t['owner']} • Создана: ${t['created_time']}',
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSystemLogsTab() {
    if (_logs.isEmpty) {
      return const Center(child: Text('Системный журнал ошибок синхронизации пуст'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _logs.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final log = _logs[i] as Map<String, dynamic>;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              const JsonEncoder.withIndent('  ').convert(log),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        );
      },
    );
  }
}