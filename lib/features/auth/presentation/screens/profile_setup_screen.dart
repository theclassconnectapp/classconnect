import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/animation/motion.dart';
import '../../../college/domain/entities/batch.dart';
import '../../../college/domain/entities/department.dart';
import '../../../college/domain/entities/user_scope.dart';
import '../../../college/domain/repositories/college_repository.dart';
import '../../../college/presentation/cubit/college_cubit.dart';
import '../../../college/presentation/cubit/college_state.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/user_role.dart';

class ProfileSetupScreen extends StatelessWidget {
  const ProfileSetupScreen({
    super.key,
    required this.firebaseUser,
    required this.role,
    required this.collegeRepository,
    required this.onSaved,
    required this.onBack,
  });

  final User firebaseUser;
  final UserRole role;
  final CollegeRepository collegeRepository;
  final Future<void> Function(AppUser profile) onSaved;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CollegeCubit>(
      create: (_) => CollegeCubit(collegeRepository: collegeRepository),
      child: _ProfileSetupContent(
        firebaseUser: firebaseUser,
        role: role,
        onSaved: onSaved,
        onBack: onBack,
      ),
    );
  }
}

class _ProfileSetupContent extends StatefulWidget {
  const _ProfileSetupContent({
    required this.firebaseUser,
    required this.role,
    required this.onSaved,
    required this.onBack,
  });

  final User firebaseUser;
  final UserRole role;
  final Future<void> Function(AppUser profile) onSaved;
  final VoidCallback onBack;

  @override
  State<_ProfileSetupContent> createState() => _ProfileSetupContentState();
}

class _ProfileSetupContentState extends State<_ProfileSetupContent> {
  static const String _collegeId = 'ukf';

  Department? _selectedDepartment;
  Batch? _selectedBatch;
  List<Department> _departments = <Department>[];
  List<Batch> _batches = <Batch>[];
  bool _saving = false;

  bool get _needsDepartment {
    return widget.role == UserRole.student ||
        widget.role == UserRole.advisor ||
        widget.role == UserRole.hod;
  }

  bool get _needsBatch {
    return widget.role == UserRole.student || widget.role == UserRole.advisor;
  }

  @override
  void initState() {
    super.initState();
    // TODO(post-launch): receive collegeId from auth flow once multi-college onboarding exists
    context.read<CollegeCubit>().loadDepartments(_collegeId);
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select department')));
      return;
    }
    if (_needsBatch && _selectedBatch == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select batch')));
      return;
    }

    final CollegeCubit cubit = context.read<CollegeCubit>();
    final Department? department = _selectedDepartment;
    final Batch? batch = _selectedBatch;

    if (widget.role == UserRole.student || widget.role == UserRole.advisor) {
      if (department == null || batch == null) {
        return;
      }
      setState(() => _saving = true);
      await cubit.assignStudentScope(
        uid: widget.firebaseUser.uid,
        collegeId: _collegeId,
        departmentId: department.id,
        batchId: batch.id,
      );
      return;
    }

    if (department != null) {
      setState(() => _saving = true);
      await cubit.assignStaffScope(
        uid: widget.firebaseUser.uid,
        collegeId: _collegeId,
        departmentId: department.id,
        batchId: batch?.id,
      );
      return;
    }

    await widget.onSaved(_buildProfile());
  }

  Future<void> _handleScopeAssigned() async {
    try {
      final AppUser profile = _buildProfile();
      final bool isStaffRole =
          widget.role == UserRole.hod || widget.role == UserRole.subjectTeacher;
      final AppUser updatedProfile = isStaffRole
          ? profile.copyWith(
              staffScopes: [
                UserScope(
                  collegeId: _collegeId,
                  departmentId: _selectedDepartment!.id.toString(),
                  batchId: widget.role == UserRole.hod
                      ? null
                      : _selectedBatch?.id.toString(),
                  role: widget.role,
                ),
              ],
            )
          : profile;
      await _addStudentToGeneralGroup(profile);
      await widget.onSaved(updatedProfile);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _addStudentToGeneralGroup(AppUser user) async {
    final Batch? batch = _selectedBatch;
    if (widget.role != UserRole.student || batch == null) {
      return;
    }

    try {
      final QuerySnapshot<Map<String, dynamic>> generalGroups =
          await FirebaseFirestore.instance
              .collection('colleges')
              .doc(_collegeId)
              .collection('groups')
              .where('batchId', isEqualTo: batch.id.toString())
              .where('isGeneral', isEqualTo: true)
              .limit(1)
              .get();

      if (generalGroups.docs.isEmpty) {
        return;
      }

      final DocumentReference<Map<String, dynamic>> groupRef =
          generalGroups.docs.first.reference;
      await FirebaseFirestore.instance.runTransaction((Transaction txn) async {
        txn.set(groupRef.collection('members').doc(user.uid), <String, dynamic>{
          'uid': user.uid,
          'name': user.name,
          'photoUrl': user.photoUrl ?? '',
          'role': user.role.id,
          'joinedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        txn.update(groupRef, <String, dynamic>{
          'members': FieldValue.arrayUnion(<String>[user.uid]),
        });
      });
    } catch (_) {
      // Membership sync should never block profile setup completion.
    }
  }

  AppUser _buildProfile() {
    return AppUser.fromFirebaseUser(
      firebaseUser: widget.firebaseUser,
      partial: AppUser(
        uid: widget.firebaseUser.uid,
        name: widget.firebaseUser.displayName ?? '',
        email: widget.firebaseUser.email ?? '',
        role: widget.role,
        dept: _selectedDepartment?.name,
        batch: _selectedBatch?.label,
        collegeId: _selectedDepartment == null ? null : _collegeId,
        departmentId: _selectedDepartment?.id,
        batchId: _selectedBatch?.id,
        deptName: _selectedDepartment?.name,
        batchLabel: _selectedBatch?.label,
        photoUrl: widget.firebaseUser.photoURL,
      ),
    );
  }

  void _syncLoadedData(CollegeState state) {
    if (state is CollegeDepartmentsLoaded) {
      _departments = state.departments;
    } else if (state is CollegeBatchesLoaded) {
      _departments = state.departments;
      _batches = state.batches;
    }
  }

  void _onDepartmentChanged(Department? department) {
    setState(() {
      _selectedDepartment = department;
      _selectedBatch = null;
      _batches = <Batch>[];
    });
    if (department != null) {
      context.read<CollegeCubit>().loadBatches(department.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CollegeCubit, CollegeState>(
      listener: (context, state) {
        if (state is CollegeDepartmentsLoaded ||
            state is CollegeBatchesLoaded) {
          setState(() => _syncLoadedData(state));
        } else if (state is CollegeScopeAssigned) {
          _handleScopeAssigned();
        } else if (state is CollegeError) {
          setState(() => _saving = false);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.message)));
        }
      },
      builder: (context, state) {
        final bool loading = state is CollegeLoading;
        return Scaffold(
          appBar: AppBar(
            title: Text('${widget.role.label} Setup'),
            leading: PressableScale(
              onTap: widget.onBack,
              child: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
              ),
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
                if (loading) const Center(child: CircularProgressIndicator()),
                if (state is CollegeError)
                  Text(
                    state.message,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (!loading && _needsDepartment)
                  DropdownButtonFormField<Department>(
                    initialValue: _selectedDepartment,
                    decoration: const InputDecoration(
                      labelText: 'Department',
                      border: OutlineInputBorder(),
                    ),
                    items: _departments
                        .map(
                          (Department department) =>
                              DropdownMenuItem<Department>(
                                value: department,
                                child: Text(department.name),
                              ),
                        )
                        .toList(),
                    onChanged: _onDepartmentChanged,
                  ),
                if (_needsDepartment) const SizedBox(height: 16),
                if (!loading && _needsBatch && _selectedDepartment != null)
                  DropdownButtonFormField<Batch>(
                    initialValue: _selectedBatch,
                    decoration: const InputDecoration(
                      labelText: 'Batch',
                      border: OutlineInputBorder(),
                    ),
                    items: _batches
                        .map(
                          (Batch batch) => DropdownMenuItem<Batch>(
                            value: batch,
                            child: Text(batch.label),
                          ),
                        )
                        .toList(),
                    onChanged: (Batch? value) {
                      setState(() => _selectedBatch = value);
                    },
                  ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving || loading ? null : _save,
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
      },
    );
  }
}
