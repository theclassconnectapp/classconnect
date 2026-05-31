import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../services/user_repository.dart';
import '../widgets/user_avatar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.user,
  });

  final AppUser user;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final UserRepository _userRepository = UserRepository();

  Future<void> _editName() async {
    final TextEditingController controller =
        TextEditingController(text: widget.user.name);
    final String? name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit display name'),
        content: TextField(controller: controller),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) {
      return;
    }
    await _userRepository.saveUser(
      AppUser(
        uid: widget.user.uid,
        name: name,
        email: widget.user.email,
        role: widget.user.role,
        dept: widget.user.dept,
        batch: widget.user.batch,
        photoUrl: widget.user.photoUrl,
      ),
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Display name updated')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                UserAvatar(
                  name: widget.user.name,
                  photoUrl: widget.user.photoUrl,
                  radius: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        widget.user.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(widget.user.email),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Role: ${widget.user.role.label}'),
            const SizedBox(height: 8),
            Text('Department: ${widget.user.dept ?? '-'}'),
            const SizedBox(height: 8),
            Text('Batch: ${widget.user.batch ?? '-'}'),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _editName,
              child: const Text('Edit display name'),
            ),
          ],
        ),
      ),
    );
  }
}

