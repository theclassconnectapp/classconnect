import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_exception.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../domain/entities/batch.dart';
import '../../domain/entities/department.dart';
import '../../domain/entities/user_scope.dart';
import '../../domain/repositories/college_repository.dart';
import '../cubit/college_cubit.dart';
import '../cubit/college_state.dart';

class StaffScopePickerScreen extends StatefulWidget {
  const StaffScopePickerScreen({
    super.key,
    required this.user,
    required this.collegeRepository,
  });

  final AppUser user;
  final CollegeRepository collegeRepository;

  @override
  State<StaffScopePickerScreen> createState() => _StaffScopePickerScreenState();
}

class _StaffScopePickerScreenState extends State<StaffScopePickerScreen> {
  @override
  Widget build(BuildContext context) {
    return BlocProvider<CollegeCubit>(
      create: (_) => CollegeCubit(collegeRepository: widget.collegeRepository),
      child: _StaffScopePickerContent(
        user: widget.user,
        collegeRepository: widget.collegeRepository,
      ),
    );
  }
}

class _StaffScopePickerContent extends StatefulWidget {
  const _StaffScopePickerContent({
    required this.user,
    required this.collegeRepository,
  });

  final AppUser user;
  final CollegeRepository collegeRepository;

  @override
  State<_StaffScopePickerContent> createState() =>
      _StaffScopePickerContentState();
}

class _StaffScopePickerContentState extends State<_StaffScopePickerContent> {
  List<Department> _departments = <Department>[];
  List<UserScope> _originalScopes = const <UserScope>[];
  final Set<String> _selectedDeptIds = <String>{};
  final Map<String, bool> _allBatchesForDept = <String, bool>{};
  final Map<String, Set<String>> _selectedBatchIds = <String, Set<String>>{};
  final Map<String, List<Batch>> _batchesByDept = <String, List<Batch>>{};
  final Set<String> _loadingBatchDeptIds = <String>{};
  final Map<String, String> _batchErrors = <String, String>{};
  bool _initializing = true;
  bool _saving = false;
  String? _initialError;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final String? collegeId = widget.user.collegeId;
    if (collegeId == null || collegeId.isEmpty) {
      setState(() {
        _initializing = false;
        _initialError = 'College is not set for this user.';
      });
      return;
    }

    setState(() {
      _initializing = true;
      _initialError = null;
    });

    try {
      final CollegeCubit cubit = context.read<CollegeCubit>();
      final List<Object?> results =
          await Future.wait<Object?>(<Future<Object?>>[
            cubit.loadDepartments(collegeId).then((_) => null),
            cubit.loadMyScopes(role: UserRole.subjectTeacher),
          ]);

      if (!mounted) {
        return;
      }

      final CollegeState state = cubit.state;
      if (state is CollegeError) {
        setState(() {
          _initializing = false;
          _initialError = state.message;
        });
        return;
      }

      final List<UserScope> scopes = List<UserScope>.unmodifiable(
        results[1]! as List<UserScope>,
      );
      setState(() {
        _departments = state is CollegeDepartmentsLoaded
            ? state.departments
            : <Department>[];
        _originalScopes = scopes;
        _applyOriginalScopes(scopes);
        _initializing = false;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _initializing = false;
        _initialError = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _initializing = false;
        _initialError = 'Something went wrong. Please try again.';
      });
    }
  }

  void _applyOriginalScopes(List<UserScope> scopes) {
    _selectedDeptIds.clear();
    _allBatchesForDept.clear();
    _selectedBatchIds.clear();

    for (final UserScope scope in scopes) {
      _selectedDeptIds.add(scope.departmentId);

      if (scope.batchId == null) {
        _allBatchesForDept[scope.departmentId] = true;
        _selectedBatchIds.remove(scope.departmentId);
      } else if (_allBatchesForDept[scope.departmentId] != true) {
        _allBatchesForDept[scope.departmentId] = false;
        _selectedBatchIds
            .putIfAbsent(scope.departmentId, () => <String>{})
            .add(scope.batchId!);
      }
    }
  }

  Future<void> _ensureBatchesLoaded(String departmentId) async {
    if (_batchesByDept.containsKey(departmentId) ||
        _loadingBatchDeptIds.contains(departmentId)) {
      return;
    }

    setState(() {
      _loadingBatchDeptIds.add(departmentId);
      _batchErrors.remove(departmentId);
    });

    try {
      final List<Batch> batches = await widget.collegeRepository.getBatches(
        departmentId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _batchesByDept[departmentId] = batches;
        _loadingBatchDeptIds.remove(departmentId);
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingBatchDeptIds.remove(departmentId);
        _batchErrors[departmentId] = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingBatchDeptIds.remove(departmentId);
        _batchErrors[departmentId] = 'Something went wrong. Please try again.';
      });
    }
  }

  void _toggleDepartment(String departmentId, bool selected) {
    setState(() {
      if (selected) {
        _selectedDeptIds.add(departmentId);
        _allBatchesForDept.putIfAbsent(departmentId, () => true);
      } else {
        _selectedDeptIds.remove(departmentId);
        _allBatchesForDept.remove(departmentId);
        _selectedBatchIds.remove(departmentId);
      }
    });
  }

  void _setBatchMode(String departmentId, _BatchMode mode) {
    setState(() {
      _allBatchesForDept[departmentId] = mode == _BatchMode.all;
      if (mode == _BatchMode.all) {
        _selectedBatchIds.remove(departmentId);
      } else {
        _selectedBatchIds.putIfAbsent(departmentId, () => <String>{});
      }
    });
    if (mode == _BatchMode.specific) {
      _ensureBatchesLoaded(departmentId);
    }
  }

  void _toggleBatch(String departmentId, String batchId, bool selected) {
    setState(() {
      final Set<String> selectedIds = _selectedBatchIds.putIfAbsent(
        departmentId,
        () => <String>{},
      );
      if (selected) {
        selectedIds.add(batchId);
      } else {
        selectedIds.remove(batchId);
      }
    });
  }

  Set<_ScopeKey> _desiredScopeKeys() {
    final Set<_ScopeKey> keys = <_ScopeKey>{};
    for (final String departmentId in _selectedDeptIds) {
      if (_allBatchesForDept[departmentId] ?? true) {
        keys.add(_ScopeKey(departmentId: departmentId));
        continue;
      }

      for (final String batchId
          in _selectedBatchIds[departmentId] ?? <String>{}) {
        keys.add(_ScopeKey(departmentId: departmentId, batchId: batchId));
      }
    }
    return keys;
  }

  Map<_ScopeKey, String?> _originalScopeIdsByKey() {
    return <_ScopeKey, String?>{
      for (final UserScope scope in _originalScopes)
        _ScopeKey(departmentId: scope.departmentId, batchId: scope.batchId):
            scope.id,
    };
  }

  String? _selectionValidationMessage() {
    for (final String departmentId in _selectedDeptIds) {
      final bool allBatches = _allBatchesForDept[departmentId] ?? true;
      if (!allBatches &&
          (_selectedBatchIds[departmentId] == null ||
              _selectedBatchIds[departmentId]!.isEmpty)) {
        return 'Select at least one batch for each specific-batches department.';
      }
    }
    return null;
  }

  Future<void> _save() async {
    final String? validationMessage = _selectionValidationMessage();
    if (validationMessage != null) {
      _showSnackBar(validationMessage);
      return;
    }

    final String? collegeId = widget.user.collegeId;
    if (collegeId == null || collegeId.isEmpty) {
      _showSnackBar('College is not set for this user.');
      return;
    }

    setState(() => _saving = true);
    try {
      final List<UserScope> freshScopes = await widget.collegeRepository
          .getMyScopes(role: UserRole.subjectTeacher);
      _originalScopes = List<UserScope>.unmodifiable(freshScopes);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      _showSnackBar('Could not verify current scopes: ${error.message}');
      return;
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      _showSnackBar('Could not verify current scopes. Please try again.');
      return;
    }

    final Set<_ScopeKey> desiredKeys = _desiredScopeKeys();
    final Map<_ScopeKey, String?> originalScopeIds = _originalScopeIdsByKey();
    final Set<_ScopeKey> originalKeys = originalScopeIds.keys.toSet();
    final Set<_ScopeKey> keysToAdd = desiredKeys.difference(originalKeys);
    final Set<_ScopeKey> keysToRemove = originalKeys.difference(desiredKeys);

    try {
      for (final _ScopeKey key in keysToAdd) {
        await widget.collegeRepository.assignStaffScope(
          uid: widget.user.uid,
          collegeId: collegeId,
          departmentId: key.departmentId,
          batchId: key.batchId,
        );
      }

      for (final _ScopeKey key in keysToRemove) {
        final String? scopeId = originalScopeIds[key];
        if (scopeId == null || scopeId.isEmpty) {
          throw const ApiException(
            statusCode: 0,
            code: 'missing_scope_id',
            message: 'A removed scope is missing its backend id.',
          );
        }
        await widget.collegeRepository.removeStaffScope(scopeId);
      }

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      _showSnackBar(error.message);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      _showSnackBar('Something went wrong. Please try again.');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Teaching scopes')),
      body: SafeArea(child: _buildBody(theme)),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: FilledButton(
          onPressed: _initializing || _saving || _initialError != null
              ? null
              : _save,
          child: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_initializing) {
      return const Center(child: CircularProgressIndicator());
    }

    final String? initialError = _initialError;
    if (initialError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                initialError,
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.error),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _loadInitialData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_departments.isEmpty) {
      return const Center(child: Text('No departments available.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _departments.length,
      separatorBuilder: (BuildContext context, int index) =>
          const SizedBox(height: 12),
      itemBuilder: (BuildContext context, int index) {
        return _buildDepartmentSection(_departments[index]);
      },
    );
  }

  Widget _buildDepartmentSection(Department department) {
    final bool selected = _selectedDeptIds.contains(department.id);
    final bool allBatches = _allBatchesForDept[department.id] ?? true;
    final _BatchMode mode = allBatches ? _BatchMode.all : _BatchMode.specific;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: <Widget>[
          CheckboxListTile(
            value: selected,
            onChanged: _saving
                ? null
                : (bool? value) {
                    _toggleDepartment(department.id, value ?? false);
                  },
            title: Text(department.name),
            subtitle: department.code.isEmpty ? null : Text(department.code),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          if (selected)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                children: <Widget>[
                  RadioGroup<_BatchMode>(
                    groupValue: mode,
                    onChanged: (_BatchMode? value) {
                      if (!_saving && value != null) {
                        _setBatchMode(department.id, value);
                      }
                    },
                    child: Column(
                      children: <Widget>[
                        RadioListTile<_BatchMode>(
                          value: _BatchMode.all,
                          enabled: !_saving,
                          title: const Text('All batches'),
                          contentPadding: EdgeInsets.zero,
                        ),
                        RadioListTile<_BatchMode>(
                          value: _BatchMode.specific,
                          enabled: !_saving,
                          title: const Text('Specific batches'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                  if (mode == _BatchMode.specific)
                    _buildBatchPicker(department.id),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBatchPicker(String departmentId) {
    if (_loadingBatchDeptIds.contains(departmentId)) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final String? error = _batchErrors[departmentId];
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
            TextButton(
              onPressed: _saving
                  ? null
                  : () => _ensureBatchesLoaded(departmentId),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final List<Batch>? batches = _batchesByDept[departmentId];
    if (batches == null) {
      _ensureBatchesLoaded(departmentId);
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (batches.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text('No batches available.'),
        ),
      );
    }

    final Set<String> selectedBatchIds =
        _selectedBatchIds[departmentId] ?? <String>{};
    return Column(
      children: batches
          .map(
            (Batch batch) => CheckboxListTile(
              value: selectedBatchIds.contains(batch.id),
              onChanged: _saving
                  ? null
                  : (bool? value) {
                      _toggleBatch(departmentId, batch.id, value ?? false);
                    },
              title: Text(batch.label),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
          )
          .toList(growable: false),
    );
  }
}

enum _BatchMode { all, specific }

class _ScopeKey {
  const _ScopeKey({required this.departmentId, this.batchId});

  final String departmentId;
  final String? batchId;

  @override
  bool operator ==(Object other) {
    return other is _ScopeKey &&
        other.departmentId == departmentId &&
        other.batchId == batchId;
  }

  @override
  int get hashCode => Object.hash(departmentId, batchId);
}
