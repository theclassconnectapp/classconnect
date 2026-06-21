import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_exception.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../domain/entities/batch.dart';
import '../../domain/entities/department.dart';
import '../../domain/entities/user_scope.dart';
import '../../domain/repositories/college_repository.dart';
import 'college_state.dart';

class CollegeCubit extends Cubit<CollegeState> {
  CollegeCubit({required CollegeRepository collegeRepository})
    : _collegeRepository = collegeRepository,
      super(const CollegeInitial());

  final CollegeRepository _collegeRepository;
  List<Department> _departments = <Department>[];

  Future<void> loadDepartments(String collegeId) async {
    emit(const CollegeLoading());
    try {
      final List<Department> departments = await _collegeRepository
          .getDepartments(collegeId);
      _departments = departments;
      emit(CollegeDepartmentsLoaded(departments));
    } on ApiException catch (error) {
      emit(CollegeError(error.message));
    } catch (_) {
      emit(const CollegeError('Something went wrong. Please try again.'));
    }
  }

  Future<void> loadBatches(String departmentId) async {
    emit(const CollegeLoading());
    try {
      final List<Batch> batches = await _collegeRepository.getBatches(
        departmentId,
      );
      emit(CollegeBatchesLoaded(_departments, batches));
    } on ApiException catch (error) {
      emit(CollegeError(error.message));
    } catch (_) {
      emit(const CollegeError('Something went wrong. Please try again.'));
    }
  }

  Future<List<UserScope>> loadMyScopes({required UserRole role}) async {
    return _collegeRepository.getMyScopes(role: role);
  }

  Future<void> assignStudentScope({
    required String uid,
    required String collegeId,
    required String departmentId,
    required String batchId,
    required String accessCode,
  }) async {
    emit(const CollegeLoading());
    try {
      await _collegeRepository.assignStudentScope(
        uid: uid,
        collegeId: collegeId,
        departmentId: departmentId,
        batchId: batchId,
        accessCode: accessCode,
      );
      emit(const CollegeScopeAssigned());
    } on ApiException catch (error) {
      emit(CollegeError(error.message));
    } catch (_) {
      emit(const CollegeError('Something went wrong. Please try again.'));
    }
  }

  Future<void> assignStaffScope({
    required String uid,
    required String collegeId,
    required String departmentId,
    String? batchId,
    required String accessCode,
  }) async {
    emit(const CollegeLoading());
    try {
      await _collegeRepository.assignStaffScope(
        uid: uid,
        collegeId: collegeId,
        departmentId: departmentId,
        batchId: batchId,
        accessCode: accessCode,
      );
      emit(const CollegeScopeAssigned());
    } on ApiException catch (error) {
      emit(CollegeError(error.message));
    } catch (_) {
      emit(const CollegeError('Something went wrong. Please try again.'));
    }
  }

  Future<void> removeScope(String scopeId) async {
    emit(const CollegeLoading());
    try {
      await _collegeRepository.removeStaffScope(scopeId);
      emit(const CollegeScopeAssigned());
    } on ApiException catch (error) {
      emit(CollegeError(error.message));
    } catch (_) {
      emit(const CollegeError('Something went wrong. Please try again.'));
    }
  }
}
