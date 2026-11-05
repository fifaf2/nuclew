import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/api_client.dart';
import '../inbox/inbox_screen.dart';
import '../profile/profile_screen.dart';
import '../support/support_screen.dart';
import '../teams/teams_screen.dart';

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
    final support = ApiClient.instance.isSupportUser;
    final screens = <Widget>[
      const TeamsScreen(),
      const InboxScreen(),
      ProfileScreen(
        onLogout: widget.onLogout,
        onProfileUpdated: () => setState(() {}),
      ),
      if (support) const SupportScreen(),
    ];
    final index = _index >= screens.length ? 0 : _index;

    return Scaffold(
      body: IndexedStack(index: index, children: screens),
      bottomNavigationBar: _BottomBar(
        index: index,
        support: support,
        onSelect: (value) => setState(() => _index = value),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final int index;
  final bool support;
  final ValueChanged<int> onSelect;

  const _BottomBar({
    required this.index,
    required this.support,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final items = <(String, IconData)>[
      ('Команды', Icons.folder_outlined),
      ('Входящие', Icons.mail_outline),
      ('Профиль', Icons.person_outline),
      if (support) ('Поддержка', Icons.headset_mic_outlined),
    ];

    return Material(
      color: kSurface,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: kLine)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 56,
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    child: InkWell(
                      onTap: () => onSelect(i),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            items[i].$2,
                            size: 20,
                            color: i == index ? kAccent : kMuted,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            items[i].$1,
                            style: TextStyle(
                              fontSize: 11,
                              color: i == index ? kAccent : kMuted,
                              fontWeight: i == index
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
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
