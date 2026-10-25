import 'package:flutter/material.dart';

import '../features/shell/root_gate.dart';
import 'theme.dart';

class NuclewApp extends StatelessWidget {
  const NuclewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nuclew',
      debugShowCheckedModeBanner: false,
      theme: nuclewTheme(),
      home: const RootGate(),
    );
  }
}
