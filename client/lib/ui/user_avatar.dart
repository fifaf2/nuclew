import 'package:flutter/material.dart';

import '../app/theme.dart';

class UserAvatar extends StatelessWidget {
  final String nickname;
  final String? avatarUrl;
  final double radius;

  const UserAvatar({
    super.key,
    required this.nickname,
    this.avatarUrl,
    this.radius = 18,
  });

  @override
  Widget build(BuildContext context) {
    final name = nickname.trim();
    final letter = name.isEmpty ? '?' : name[0].toUpperCase();
    final url = avatarUrl?.trim() ?? '';
    final fallback = Text(
      letter,
      style: TextStyle(
        fontSize: radius * 0.72,
        fontWeight: FontWeight.w600,
        color: kInk,
      ),
    );

    if (url.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: const Color(0xFFE4DDD2),
        child: fallback,
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFE4DDD2),
      child: ClipOval(
        child: Image.network(
          url,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => fallback,
        ),
      ),
    );
  }
}
