import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../data/api_client.dart';
import '../../ui/snack.dart';

class TaskScreen extends StatefulWidget {
  final int taskId;
  final String myRole;

  const TaskScreen({super.key, required this.taskId, required this.myRole});

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  Map<String, dynamic>? _task;
  List<dynamic> _changes = [];
  List<dynamic> _remarks = [];
  List<dynamic> _comments = [];

  bool _loading = true;
  bool _editing = false;

  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();

  bool get _isOwner => widget.myRole == 'владелец команды';
  bool get _isGuest => widget.myRole == 'гость';

  int? get _myId => ApiClient.instance.currentUser?['user_id'] as int?;

  bool get _mine =>
      _task != null &&
      _task!['assignee_user_id'] != null &&
      _task!['assignee_user_id'] == _myId;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_task == null && !_loading && mounted) {
      setState(() => _loading = true);
    }
    try {
      final api = ApiClient.instance;
      final results = await Future.wait([
        api.get('/api/v1/tasks/${widget.taskId}'),
        api.get('/api/v1/tasks/${widget.taskId}/remarks'),
        api.get('/api/v1/tasks/${widget.taskId}/changes'),
        api.get('/api/v1/tasks/${widget.taskId}/comments'),
      ]);
      if (!mounted) return;
      setState(() {
        _task = results[0] as Map<String, dynamic>;
        _remarks = results[1] as List<dynamic>;
        _changes = results[2] as List<dynamic>;
        _comments = results[3] as List<dynamic>;
        _titleCtrl.text = _task!['title']?.toString() ?? '';
        _contentCtrl.text = _task!['content']?.toString() ?? '';
      });
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _claim() async {
    try {
      await ApiClient.instance.post('/api/v1/tasks/${widget.taskId}/claim');
      await _load();
      if (mounted) showSnack(context, 'Задача у вас');
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), isError: true);
    }
  }

  Future<void> _save() async {
    try {
      await ApiClient.instance.patch('/api/v1/tasks/${widget.taskId}', {
        'title': _titleCtrl.text.trim(),
        'content': _contentCtrl.text,
      });
      if (mounted) setState(() => _editing = false);
      await _load();
      if (mounted) showSnack(context, 'Сохранили');
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), isError: true);
    }
  }

  Future<void> _complete() async {
    try {
      if (_editing) await _save();
      await ApiClient.instance.post('/api/v1/tasks/${widget.taskId}/complete');
      await _load();
      if (mounted) showSnack(context, 'Задача завершена');
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), isError: true);
    }
  }

  Future<void> _unlock() async {
    try {
      await ApiClient.instance.post('/api/v1/tasks/${widget.taskId}/unlock');
      await _load();
      if (mounted) showSnack(context, 'Блокировку сняли');
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), isError: true);
    }
  }

  Future<void> _archive() async {
    try {
      await ApiClient.instance.post('/api/v1/tasks/${widget.taskId}/archive');
      if (!mounted) return;
      showSnack(context, 'Убрали в архив');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), isError: true);
    }
  }

  Future<void> _export() async {
    try {
      final md = await ApiClient.instance.getRawText(
        '/api/v1/tasks/${widget.taskId}/export',
      );
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Экспорт'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: SelectableText(
                md,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Закрыть'),
            ),
            FilledButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: md));
                Navigator.pop(ctx);
                showSnack(context, 'Скопировали');
              },
              child: const Text('Копировать'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), isError: true);
    }
  }

  Future<void> _addRemark({String? fragment, int? changeId}) async {
    final fragCtrl = TextEditingController(text: fragment ?? '');
    final textCtrl = TextEditingController();
    var selected =
        changeId ??
        (_changes.isNotEmpty ? _changes.first['change_id'] as int? : null);

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => AlertDialog(
          title: const Text('Замечание'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: fragCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Фрагмент',
                    hintText: 'Строка 14: ## API',
                  ),
                ),
                if (_changes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    initialValue: selected,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'К правке'),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Без привязки'),
                      ),
                      ..._changes.map(
                        (change) => DropdownMenuItem<int?>(
                          value: change['change_id'] as int,
                          child: Text(
                            '#${change['change_id']} ${change['author']}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) => setModal(() => selected = value),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: textCtrl,
                  maxLines: 4,
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
                if (fragCtrl.text.trim().isEmpty ||
                    textCtrl.text.trim().isEmpty) {
                  showSnack(context, 'Нужны фрагмент и текст', isError: true);
                  return;
                }
                try {
                  await ApiClient.instance.post(
                    '/api/v1/tasks/${widget.taskId}/remarks',
                    {
                      'fragment_identifier': fragCtrl.text.trim(),
                      'text': textCtrl.text.trim(),
                      'change_id': selected,
                    },
                  );
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  await _load();
                  if (mounted) {
                    showSnack(context, 'Замечание ушло, задача на доработке');
                  }
                } catch (e) {
                  if (mounted) showSnack(context, e.toString(), isError: true);
                }
              },
              child: const Text('Отправить'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _closeRemark(int id) async {
    try {
      await ApiClient.instance.patch('/api/v1/remarks/$id');
      await _load();
      if (mounted) showSnack(context, 'Закрыли');
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), isError: true);
    }
  }

  Future<void> _sendComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    try {
      await ApiClient.instance.post('/api/v1/tasks/${widget.taskId}/comments', {
        'text': text,
      });
      _commentCtrl.clear();
      await _load();
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _task == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Задача ${widget.taskId}')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final task = _task!;
    final status = task['status']?.toString() ?? '';
    final hasAssignee = task['assignee_user_id'] != null;
    // «на доработке» можно взять, только если исполнителя нет или это вы.
    final canClaim =
        !_isGuest &&
        (status == 'свободна' ||
            (status == 'на доработке' && (!hasAssignee || _mine)));
    final working = _mine && status == 'в работе';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          task['title']?.toString() ?? 'Задача',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Экспорт',
            onPressed: _export,
            icon: const Icon(Icons.download_outlined),
          ),
          IconButton(
            tooltip: 'Обновить',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
          if (_isOwner)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'unlock') _unlock();
                if (value == 'archive') _archive();
              },
              itemBuilder: (_) => [
                if (status == 'в работе')
                  const PopupMenuItem(
                    value: 'unlock',
                    child: Text('Снять блокировку'),
                  ),
                const PopupMenuItem(value: 'archive', child: Text('В архив')),
              ],
            ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: [
            const Tab(text: 'Текст'),
            Tab(text: 'Замечания (${_remarks.length})'),
            Tab(text: 'Правки (${_changes.length})'),
            Tab(text: 'Комментарии (${_comments.length})'),
          ],
        ),
      ),
      body: Column(
        children: [
          _toolbar(status, canClaim, working),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _document(working),
                _remarksTab(),
                _changesTab(),
                _commentsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolbar(String status, bool canClaim, bool working) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 0,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            '#${widget.taskId}',
            style: const TextStyle(color: kMuted, fontSize: 13),
          ),
          Text(
            status,
            style: TextStyle(
              color: taskStatusColor(status),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          if (_isGuest)
            const Text(
              'только чтение',
              style: TextStyle(color: kMuted, fontSize: 12),
            ),
          if (canClaim)
            FilledButton(
              onPressed: _claim,
              child: const Text('Взять в работу'),
            ),
          if (working) ...[
            TextButton(
              onPressed: () {
                if (_editing) {
                  _save();
                } else {
                  setState(() => _editing = true);
                }
              },
              child: Text(_editing ? 'Сохранить' : 'Править'),
            ),
            TextButton(onPressed: _complete, child: const Text('Завершить')),
          ],
          if (!_isGuest)
            TextButton(
              onPressed: () => _addRemark(),
              child: const Text('Замечание'),
            ),
        ],
      ),
    );
  }

  Widget _document(bool working) {
    if (_editing && working) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          children: [
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'Название'),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _contentCtrl,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                  height: 1.4,
                ),
                decoration: const InputDecoration(
                  labelText: 'Текст',
                  alignLabelWithHint: true,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final raw = _task!['content']?.toString() ?? '';
    final lines = raw.isEmpty ? const ['пока пусто'] : raw.split('\n');
    final head = _isGuest ? 0 : 1;

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: lines.length + head,
      itemBuilder: (context, index) {
        if (head == 1 && index == 0) {
          return const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              'Строку можно нажать — откроется замечание.',
              style: TextStyle(fontSize: 12, color: kMuted),
            ),
          );
        }
        final lineIndex = index - head;
        final line = lines[lineIndex];
        final number = lineIndex + 1;
        final header = line.trimLeft().startsWith('#');
        return InkWell(
          onTap: _isGuest
              ? null
              : () {
                  // Сервер хранит привязку именно такой строкой.
                  _addRemark(fragment: 'Строка $number: $line');
                },
          child: ColoredBox(
            color: lineIndex.isEven ? const Color(0xFFF7F4EE) : kSurface,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 36,
                    child: Text(
                      '$number',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: kMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      line.isEmpty ? ' ' : line,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: header ? 15 : 13.5,
                        height: 1.35,
                        fontWeight: header ? FontWeight.w600 : FontWeight.w400,
                        color: kInk,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _remarksTab() {
    if (_remarks.isEmpty) {
      return const Center(
        child: Text('Замечаний нет', style: TextStyle(color: kMuted)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _remarks.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (context, i) {
        final remark = _remarks[i] as Map<String, dynamic>;
        final open = remark['status'] == 'открыто';
        return DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: open ? const Color(0xFF8A5A12) : const Color(0xFF2A6B45),
                width: 3,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 0, 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  remark['fragment_identifier']?.toString() ?? '',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  remark['text']?.toString() ?? '',
                  style: const TextStyle(height: 1.35),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    remark['author'],
                    remark['status'],
                    if (remark['change_id'] != null)
                      'правка ${remark['change_id']}',
                  ].join(' · '),
                  style: const TextStyle(color: kMuted, fontSize: 12),
                ),
                if (!_isGuest && open)
                  TextButton(
                    onPressed: () => _closeRemark(remark['remark_id'] as int),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Закрыть'),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _changesTab() {
    if (_changes.isEmpty) {
      return const Center(
        child: Text('Правок ещё не было', style: TextStyle(color: kMuted)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _changes.length,
      separatorBuilder: (_, _) => const SizedBox(height: 18),
      itemBuilder: (context, i) {
        final change = _changes[i] as Map<String, dynamic>;
        final diff = change['diff_content']?.toString() ?? '';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Правка ${change['change_id']} · ${change['author']}, ${change['author_role']}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(
              '${change['change_date']} ${change['change_time']}',
              style: const TextStyle(color: kMuted, fontSize: 12),
            ),
            const SizedBox(height: 8),
            DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFF7F4EE),
                border: Border.all(color: kLine),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final line in diff.split('\n')) _diffLine(line),
                  ],
                ),
              ),
            ),
            if (!_isGuest)
              TextButton(
                onPressed: () => _addRemark(
                  fragment: 'Ревизия #${change['change_id']}',
                  changeId: change['change_id'] as int,
                ),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Замечание к правке'),
              ),
          ],
        );
      },
    );
  }

  // Префиксы как в unified diff: «+» добавлено, «-» удалено, «@@» заголовок хунка.
  Widget _diffLine(String line) {
    var background = Colors.transparent;
    var foreground = kInk;
    if (line.startsWith('+') && !line.startsWith('+++')) {
      background = const Color(0xFFE5F2E8);
      foreground = const Color(0xFF1E6B3A);
    } else if (line.startsWith('-') && !line.startsWith('---')) {
      background = const Color(0xFFF8E6E4);
      foreground = const Color(0xFF9C3B32);
    } else if (line.startsWith('@@')) {
      background = const Color(0xFFE7EEF6);
      foreground = const Color(0xFF2C5F8A);
    }
    return ColoredBox(
      color: background,
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          child: Text(
            line.isEmpty ? ' ' : line,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              height: 1.35,
              color: foreground,
            ),
          ),
        ),
      ),
    );
  }

  Widget _commentsTab() {
    return Column(
      children: [
        Expanded(
          child: _comments.isEmpty
              ? const Center(
                  child: Text(
                    'Комментариев нет',
                    style: TextStyle(color: kMuted),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  itemCount: _comments.length,
                  separatorBuilder: (_, _) => const Divider(height: 16),
                  itemBuilder: (context, i) {
                    final comment = _comments[i] as Map<String, dynamic>;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              comment['author']?.toString() ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              comment['created_time']?.toString() ?? '',
                              style: const TextStyle(
                                color: kMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          comment['text']?.toString() ?? '',
                          style: const TextStyle(height: 1.35),
                        ),
                      ],
                    );
                  },
                ),
        ),
        if (!_isGuest)
          DecoratedBox(
            decoration: const BoxDecoration(
              color: kSurface,
              border: Border(top: BorderSide(color: kLine)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Комментарий',
                        ),
                        onSubmitted: (_) => _sendComment(),
                      ),
                    ),
                    TextButton(
                      onPressed: _sendComment,
                      child: const Text('Отправить'),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
