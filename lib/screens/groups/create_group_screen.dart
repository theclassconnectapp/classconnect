import 'package:flutter/material.dart';

import '../../constants/app_constants.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({
    super.key,
    required this.allowGeneral,
  });

  final bool allowGeneral;

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String? _dept;
  String? _batch;
  String _type = 'subject';

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_dept == null || _batch == null || _nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter name, department and batch.')),
      );
      return;
    }
    Navigator.of(context).pop(<String, String>{
      'name': _nameController.text.trim(),
      'description': _descriptionController.text.trim(),
      'dept': _dept!,
      'batch': _batch!,
      'type': _type,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Group')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Group Type',
            ),
            items: <DropdownMenuItem<String>>[
              if (widget.allowGeneral)
                const DropdownMenuItem(value: 'general', child: Text('General')),
              const DropdownMenuItem(value: 'subject', child: Text('Subject')),
            ],
            onChanged: (String? value) => setState(() => _type = value ?? 'subject'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Group Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _dept,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Department',
            ),
            items: kDepartments
                .map((String value) =>
                    DropdownMenuItem<String>(value: value, child: Text(value)))
                .toList(),
            onChanged: (String? value) => setState(() => _dept = value),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _batch,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Batch',
            ),
            items: kBatches
                .map((String value) =>
                    DropdownMenuItem<String>(value: value, child: Text(value)))
                .toList(),
            onChanged: (String? value) => setState(() => _batch = value),
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: _submit, child: const Text('Create')),
        ],
      ),
    );
  }
}
