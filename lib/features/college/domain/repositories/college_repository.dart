import '../entities/batch.dart';
import '../entities/department.dart';
import '../entities/user_scope.dart';
import '../../../auth/domain/entities/user_role.dart';

abstract class CollegeRepository {
  Future<List<Department>> getDepartments(String collegeId);

  Future<List<Batch>> getBatches(String departmentId);

  Future<List<UserScope>> getMyScopes({required UserRole role});

  Future<void> assignStudentScope({
    required String uid,
    required String collegeId,
    required String departmentId,
    required String batchId,
  });

  Future<void> assignStaffScope({
    required String uid,
    required String collegeId,
    required String departmentId,
    String? batchId,
  });

  Future<void> removeStaffScope(String scopeId);
}
