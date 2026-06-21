import 'package:flutter/material.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.radius = 20,
  });

  final String name;
  final String? photoUrl;
  final double radius;

  String get _initials {
    final List<String> parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((String p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return '?';
    }
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    if (photoUrl == null || photoUrl!.isEmpty) {
      return CircleAvatar(radius: radius, child: Text(_initials));
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: colorScheme.surfaceContainerHighest,
      child: ClipOval(
        child: Image.network(
          photoUrl!,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder:
              (BuildContext context, Object error, StackTrace? stackTrace) =>
                  Center(child: Text(_initials)),
        ),
      ),
    );
  }
}
