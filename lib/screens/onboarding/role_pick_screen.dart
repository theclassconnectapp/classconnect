import 'package:flutter/material.dart';

import '../../models/user_role.dart';

class RolePickScreen extends StatelessWidget {
  const RolePickScreen({super.key, required this.onRoleSelected});

  final ValueChanged<UserRole> onRoleSelected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose Your Role')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          const Text(
            'Select how you use ClassConnect.',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          for (final UserRole role in UserRole.values)
            Card(
              child: ListTile(
                title: Text(role.label),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () => onRoleSelected(role),
              ),
            ),
        ],
      ),
    );
  }
}
