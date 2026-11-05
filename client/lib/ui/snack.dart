import 'package:flutter/material.dart';

import '../app/theme.dart';

void showSnack(BuildContext context, String message, {bool isError = false}) {
  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(content: Text(message), backgroundColor: isError ? kBad : kInk),
  );
}
