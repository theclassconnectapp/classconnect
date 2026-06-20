import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../domain/entities/batch.dart';
import '../../domain/entities/department.dart';
import '../../domain/repositories/college_repository.dart';
import '../models/batch_model.dart';
import '../models/department_model.dart';

class CollegeRepositoryImpl implements CollegeRepository {
  const CollegeRepositoryImpl({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<List<Department>> getDepartments(String collegeId) async {
    try {
      final Object? response = await _apiClient.get(
        '/api/v1/colleges/$collegeId/departments',
      );
      return _readList(
        response,
      ).map(DepartmentModel.fromJson).toList(growable: false);
    } on ApiException {
      rethrow;
    }
  }

  @override
  Future<List<Batch>> getBatches(String departmentId) async {
    try {
      final Object? response = await _apiClient.get(
        '/api/v1/departments/$departmentId/batches',
      );
      return _readList(
        response,
      ).map(BatchModel.fromJson).toList(growable: false);
    } on ApiException {
      rethrow;
    }
  }

  @override
  Future<void> assignStudentScope({
    required String uid,
    required String collegeId,
    required String departmentId,
    required String batchId,
  }) async {
    try {
      await _apiClient.post(
        '/api/v1/scopes/student',
        body: <String, Object?>{
          'uid': uid,
          'college_id': collegeId,
          'department_id': departmentId,
          'batch_id': batchId,
        },
      );
    } on ApiException {
      rethrow;
    }
  }

  @override
  Future<void> assignStaffScope({
    required String uid,
    required String collegeId,
    required String departmentId,
    String? batchId,
  }) async {
    try {
      await _apiClient.post(
        '/api/v1/scopes/staff',
        body: <String, Object?>{
          'uid': uid,
          'college_id': collegeId,
          'department_id': departmentId,
          'batch_id': ?batchId,
        },
      );
    } on ApiException {
      rethrow;
    }
  }

  List<Map<String, Object?>> _readList(Object? response) {
    final Object? payload = response is Map<String, Object?>
        ? response['data'] ?? response['items']
        : response;
    if (payload is List<Object?>) {
      return payload.whereType<Map<String, Object?>>().toList(growable: false);
    }
    throw const ApiException(
      statusCode: 0,
      code: 'invalid_response',
      message: 'Backend returned an unexpected response.',
    );
  }
}
