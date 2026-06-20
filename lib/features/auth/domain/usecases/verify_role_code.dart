import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../entities/user_role.dart';

class VerifyRoleCode {
  const VerifyRoleCode({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<UserRole> call(String code) async {
    final Object? response = await _apiClient.post(
      '/api/v1/auth/verify-role-code',
      body: <String, Object?>{'code': code},
    );

    if (response is Map<String, Object?>) {
      final Object? role = response['role'];
      if (role is String && role.isNotEmpty) {
        return UserRole.fromId(role);
      }
    }

    throw const ApiException(
      statusCode: 0,
      code: 'invalid_response',
      message: 'Backend returned an unexpected response.',
    );
  }
}
