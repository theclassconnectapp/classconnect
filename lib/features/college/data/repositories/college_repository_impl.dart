import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../domain/entities/batch.dart';
import '../../domain/entities/department.dart';
import '../../domain/entities/user_scope.dart';
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
  Future<List<UserScope>> getMyScopes({required UserRole role}) async {
    try {
      final Object? response = await _apiClient.get('/api/v1/scopes/me');
      return _readScopes(response)
          .map((Map<String, Object?> json) => _userScopeFromJson(json, role))
          .toList(growable: false);
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

  @override
  Future<void> removeStaffScope(String scopeId) async {
    try {
      await _apiClient.delete('/api/v1/scopes/${Uri.encodeComponent(scopeId)}');
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

  List<Map<String, Object?>> _readScopes(Object? response) {
    final Object? payload = response is Map<String, Object?>
        ? response['scopes']
        : null;
    if (payload is List<Object?>) {
      return payload.whereType<Map<String, Object?>>().toList(growable: false);
    }
    throw const ApiException(
      statusCode: 0,
      code: 'invalid_response',
      message: 'Backend returned an unexpected response.',
    );
  }

  UserScope _userScopeFromJson(Map<String, Object?> json, UserRole role) {
    return UserScope(
      id: json['id'] as String?,
      collegeId: _readString(json, 'collegeId', 'college_id'),
      departmentId: _readString(json, 'departmentId', 'department_id'),
      batchId: _readNullableString(json, 'batchId', 'batch_id'),
      role: role,
    );
  }

  String _readString(Map<String, Object?> json, String key, [String? altKey]) {
    final Object? value = json[key] ?? (altKey == null ? null : json[altKey]);
    if (value is String) {
      return value;
    }
    throw const ApiException(
      statusCode: 0,
      code: 'invalid_response',
      message: 'Backend returned an unexpected response.',
    );
  }

  String? _readNullableString(
    Map<String, Object?> json,
    String key, [
    String? altKey,
  ]) {
    final Object? value = json[key] ?? (altKey == null ? null : json[altKey]);
    return value is String ? value : null;
  }
}
