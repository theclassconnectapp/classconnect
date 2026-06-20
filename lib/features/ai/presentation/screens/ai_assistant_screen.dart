import 'package:flutter/material.dart';

enum AiScope { semester, group }

class AiAssistantScreen extends StatelessWidget {
  const AiAssistantScreen({
    super.key,
    required this.scope,
    required this.semesterId,
    this.groupId,
  });

  final AiScope scope;
  final String semesterId;
  final String? groupId;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Ask AI'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
      ),
      body: Center(
        child: Text('Coming soon', style: TextStyle(fontSize: 16, color: colorScheme.onSurface)),
      ),
    );
  }
}