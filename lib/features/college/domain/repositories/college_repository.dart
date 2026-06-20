import '../entities/batch.dart';
import '../entities/department.dart';

abstract class CollegeRepository {
  Future<List<Department>> getDepartments(String collegeId);

  Future<List<Batch>> getBatches(String departmentId);

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
}
