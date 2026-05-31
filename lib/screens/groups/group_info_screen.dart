import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/user_role.dart';
import '../../services/group_repository.dart';

class GroupInfoScreen extends StatefulWidget {
  const GroupInfoScreen({
    super.key,
    required this.groupId,
    required this.groupData,
    required this.currentUser,
    required this.groupRepository,
  });

  final String groupId;
  final Map<String, dynamic> groupData;
  final AppUser currentUser;
  final GroupRepository groupRepository;

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  bool _saving = false;

  bool get _isSuperAdmin {
    final String dept = (widget.groupData['dept'] as String?) ?? '';
    return widget.currentUser.role == UserRole.hod && widget.currentUser.dept == dept;
  }

  bool get _isAdmin {
    final List<dynamic> admins = (widget.groupData['admins'] as List<dynamic>?) ?? <dynamic>[];
    return admins.contains(widget.currentUser.uid) || _isSuperAdmin;
  }

  Future<void> _editGroup() async {
    final TextEditingController nameController = TextEditingController(
      text: (widget.groupData['name'] as String?) ?? '',
    );
    final TextEditingController descController = TextEditingController(
      text: (widget.groupData['description'] as String?) ?? '',
    );
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Group'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _saving = true);
    await widget.groupRepository.updateGroupInfo(
      groupId: widget.groupId,
      name: nameController.text,
      description: descController.text,
    );
    if (!mounted) return;
    setState(() => _saving = false);
  }

  Future<void> _setPhoto() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      withData: true,
      allowedExtensions: <String>['png', 'jpg', 'jpeg'],
    );
    if (result == null || result.files.isEmpty) return;
    setState(() => _saving = true);
    final String url = await widget.groupRepository.uploadGroupPhoto(
      groupId: widget.groupId,
      file: result.files.first,
    );
    await widget.groupRepository.setGroupPhotoUrl(groupId: widget.groupId, photoUrl: url);
    if (!mounted) return;
    setState(() => _saving = false);
  }

  Future<void> _removePhoto() async {
    setState(() => _saving = true);
    await widget.groupRepository.setGroupPhotoUrl(groupId: widget.groupId, photoUrl: null);
    if (!mounted) return;
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final String name = (widget.groupData['name'] as String?) ?? '';
    final String desc = (widget.groupData['description'] as String?) ?? '';
    final String? photoUrl = widget.groupData['photoUrl'] as String?;
    return Scaffold(
      appBar: AppBar(title: const Text('Group Info')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          CircleAvatar(
            radius: 34,
            backgroundImage:
                photoUrl != null && photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
            child: photoUrl == null || photoUrl.isEmpty
                ? Text(name.isEmpty ? '?' : name[0].toUpperCase())
                : null,
          ),
          const SizedBox(height: 12),
          Text(name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(desc),
          const SizedBox(height: 20),
          if (_isAdmin) ...<Widget>[
            FilledButton.icon(
              onPressed: _saving ? null : _editGroup,
              icon: const Icon(Icons.edit),
              label: const Text('Edit group'),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _saving ? null : _setPhoto,
              icon: const Icon(Icons.photo_camera),
              label: const Text('Set/Change photo'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _saving ? null : _removePhoto,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Remove photo'),
            ),
          ],
        ],
      ),
    );
  }
}

