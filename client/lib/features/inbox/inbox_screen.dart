import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/api_client.dart';
import '../../ui/snack.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  List<dynamic> _items = [];
  bool _unreadOnly = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_items.isEmpty && !_loading && mounted) {
      setState(() => _loading = true);
    }
    try {
      final data = await ApiClient.instance.get(
        '/api/v1/users/me/notifications',
        {'unread_only': _unreadOnly.toString()},
      );
      if (!mounted) return;
      setState(() => _items = data as List<dynamic>);
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleRead(Map<String, dynamic> item) async {
    final unread = item['status'] == 'не прочитано';
    try {
      await ApiClient.instance.patch(
        '/api/v1/notifications/${item['notification_id']}',
        {'read': unread},
      );
      await _load();
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), isError: true);
    }
  }

  Future<void> _writeSupport() async {
    final subjectCtrl = TextEditingController();
    final textCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('В поддержку'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: subjectCtrl,
              decoration: const InputDecoration(labelText: 'Тема'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textCtrl,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Что случилось'),
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
              final subject = subjectCtrl.text.trim();
              final text = textCtrl.text.trim();
              if (subject.isEmpty || text.isEmpty) {
                showSnack(context, 'Нужны тема и текст', isError: true);
                return;
              }
              try {
                await ApiClient.instance.post('/api/v1/support/requests', {
                  'subject': subject,
                  'text': text,
                });
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (mounted) showSnack(context, 'Отправили');
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
        title: const Text('Входящие'),
        actions: [
          TextButton(onPressed: _writeSupport, child: const Text('Написать')),
        ],
      ),
      body: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() => _unreadOnly = !_unreadOnly);
              _load();
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Icon(
                    _unreadOnly
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                    size: 18,
                    color: _unreadOnly ? kAccent : kMuted,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Только непрочитанные',
                    style: TextStyle(color: kMuted, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _items.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: const [
                              SizedBox(height: 72),
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
                            itemCount: _items.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1, indent: 16),
                            itemBuilder: (context, i) {
                              final item = _items[i] as Map<String, dynamic>;
                              final unread = item['status'] == 'не прочитано';
                              return InkWell(
                                onTap: () => _toggleRead(item),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    12,
                                    16,
                                    12,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['text']?.toString() ?? '',
                                        style: TextStyle(
                                          fontWeight: unread
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                          height: 1.3,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${item['sent_time']} · ${unread ? 'не прочитано' : 'прочитано'}',
                                        style: const TextStyle(
                                          color: kMuted,
                                          fontSize: 12,
                                        ),
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
