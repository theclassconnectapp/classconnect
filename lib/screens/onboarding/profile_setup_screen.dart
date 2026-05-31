import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../constants/app_constants.dart';
import '../../models/app_user.dart';
import '../../models/user_role.dart';
import '../../services/user_repository.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({
    super.key,
    required this.firebaseUser,
    required this.role,
    required this.userRepository,
    required this.onSaved,
    required this.onBack,
  });

  final User firebaseUser;
  final UserRole role;
  final UserRepository userRepository;
  final Future<void> Function(AppUser profile) onSaved;
  final VoidCallback onBack;

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  String? _selectedDepartment;
  String? _selectedBatch;
  bool _saving = false;

  bool get _needsDepartment {
    return widget.role == UserRole.student ||
        widget.role == UserRole.advisor ||
        widget.role == UserRole.hod;
  }

  bool get _needsBatch {
    return widget.role == UserRole.student || widget.role == UserRole.advisor;
  }

  String _subtitle() {
    switch (widget.role) {
      case UserRole.student:
        return 'Select your department and batch.';
      case UserRole.advisor:
        return 'Select department and batch you manage.';
      case UserRole.hod:
        return 'Select your department.';
      case UserRole.subjectTeacher:
        return '';
    }
  }

  Future<void> _save() async {
    if (_needsDepartment && _selectedDepartment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select department')),
      );
      return;
    }
    if (_needsBatch && _selectedBatch == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select batch')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final AppUser profile = widget.userRepository.profileFromFirebaseUser(
        firebaseUser: widget.firebaseUser,
        partial: AppUser(
          uid: widget.firebaseUser.uid,
          name: widget.firebaseUser.displayName ?? '',
          email: widget.firebaseUser.email ?? '',
          role: widget.role,
          dept: _selectedDepartment,
          batch: _selectedBatch,
          photoUrl: widget.firebaseUser.photoURL,
        ),
      );
      await widget.onSaved(profile);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.role.label} Setup'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              _subtitle(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (_needsDepartment)
              DropdownButtonFormField<String>(
                initialValue: _selectedDepartment,
                decoration: const InputDecoration(
                  labelText: 'Department',
                  border: OutlineInputBorder(),
                ),
                items: kDepartments
                    .map(
                      (String dept) => DropdownMenuItem<String>(
                        value: dept,
                        child: Text(dept),
                      ),
                    )
                    .toList(),
                onChanged: (String? value) {
                  setState(() => _selectedDepartment = value);
                },
              ),
            if (_needsDepartment) const SizedBox(height: 16),
            if (_needsBatch)
              DropdownButtonFormField<String>(
                initialValue: _selectedBatch,
                decoration: const InputDecoration(
                  labelText: 'Batch',
                  border: OutlineInputBorder(),
                ),
                items: kBatches
                    .map(
                      (String batch) => DropdownMenuItem<String>(
                        value: batch,
                        child: Text(batch),
                      ),
                    )
                    .toList(),
                onChanged: (String? value) {
                  setState(() => _selectedBatch = value);
                },
              ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save and Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
