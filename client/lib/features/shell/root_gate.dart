import 'package:flutter/material.dart';

import '../../data/api_client.dart';
import '../auth/auth_screen.dart';
import 'main_shell.dart';

class RootGate extends StatefulWidget {
  const RootGate({super.key});

  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> {
  bool _authenticated = false;

  void _onLogin() => setState(() => _authenticated = true);

  void _onLogout() {
    // Токен живёт в ApiClient, этот экран только переключает вход и оболочку.
    ApiClient.instance.clearSession();
    setState(() => _authenticated = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_authenticated) {
      return AuthScreen(onLoginSuccess: _onLogin);
    }
    return MainShell(onLogout: _onLogout);
  }
}
