import 'package:flutter/material.dart';

import '../../models/app_user.dart';

class RoleDashboardShell extends StatelessWidget {
  const RoleDashboardShell({
    super.key,
    required this.title,
    required this.user,
    required this.onSignOut,
    required this.subtitle,
  });

  final String title;
  final AppUser user;
  final VoidCallback onSignOut;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: <Widget>[
          IconButton(
            tooltip: 'Sign out',
            onPressed: onSignOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Welcome, ${user.name}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(subtitle),
            const SizedBox(height: 16),
            if (user.photoUrl != null)
              CircleAvatar(
                radius: 28,
                backgroundImage: NetworkImage(user.photoUrl!),
              ),
            const SizedBox(height: 24),
            const Text('Placeholder: subject groups and media will appear here.'),
          ],
        ),
      ),
    );
  }
}
