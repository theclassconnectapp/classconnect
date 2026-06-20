import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../college/domain/entities/batch.dart';
import '../../../college/domain/entities/department.dart';
import '../../../college/domain/repositories/college_repository.dart';
import '../../../college/presentation/cubit/college_cubit.dart';
import '../../../college/presentation/cubit/college_state.dart';

class CreateGroupScreen extends StatelessWidget {
  const CreateGroupScreen({
    super.key,
    required this.allowGeneral,
    required this.collegeRepository,
  });

  final bool allowGeneral;
  final CollegeRepository collegeRepository;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CollegeCubit>(
      create: (_) => CollegeCubit(collegeRepository: collegeRepository),
      child: _CreateGroupContent(allowGeneral: allowGeneral),
    );
  }
}

class _CreateGroupContent extends StatefulWidget {
  const _CreateGroupContent({required this.allowGeneral});

  final bool allowGeneral;

  @override
  State<_CreateGroupContent> createState() => _CreateGroupContentState();
}

class _CreateGroupContentState extends State<_CreateGroupContent> {
  static const String _collegeId = 'ukf';

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  Department? _department;
  Batch? _batch;
  List<Department> _departments = <Department>[];
  List<Batch> _batches = <Batch>[];
  String _type = 'subject';

  @override
  void initState() {
    super.initState();
    context.read<CollegeCubit>().loadDepartments(_collegeId);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    final Department? department = _department;
    final Batch? batch = _batch;
    if (department == null ||
        batch == null ||
        _nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter name, department and batch.')),
      );
      return;
    }
    Navigator.of(context).pop(<String, String>{
      'name': _nameController.text.trim(),
      'description': _descriptionController.text.trim(),
      'dept': department.name,
      'batch': batch.label,
      'type': _type,
    });
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
      _department = department;
      _batch = null;
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
        } else if (state is CollegeError) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.message)));
        }
      },
      builder: (context, state) {
        final bool loading = state is CollegeLoading;
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
                    const DropdownMenuItem(
                      value: 'general',
                      child: Text('General'),
                    ),
                  const DropdownMenuItem(
                    value: 'subject',
                    child: Text('Subject'),
                  ),
                ],
                onChanged: (String? value) =>
                    setState(() => _type = value ?? 'subject'),
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
              if (loading) const Center(child: CircularProgressIndicator()),
              if (state is CollegeError)
                Text(
                  state.message,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (!loading)
                DropdownButtonFormField<Department>(
                  initialValue: _department,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Department',
                  ),
                  items: _departments
                      .map(
                        (Department department) => DropdownMenuItem<Department>(
                          value: department,
                          child: Text(department.name),
                        ),
                      )
                      .toList(),
                  onChanged: _onDepartmentChanged,
                ),
              const SizedBox(height: 12),
              if (!loading && _department != null)
                DropdownButtonFormField<Batch>(
                  initialValue: _batch,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Batch',
                  ),
                  items: _batches
                      .map(
                        (Batch batch) => DropdownMenuItem<Batch>(
                          value: batch,
                          child: Text(batch.label),
                        ),
                      )
                      .toList(),
                  onChanged: (Batch? value) => setState(() => _batch = value),
                ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: loading ? null : _submit,
                child: const Text('Create'),
              ),
            ],
          ),
        );
      },
    );
  }
}
