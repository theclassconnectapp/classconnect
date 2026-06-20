import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../domain/repositories/ai_repository.dart';

class AiRepositoryImpl implements AiRepository {
  const AiRepositoryImpl({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<String> generateResponse(String prompt) async {
    final Object? response = await _apiClient.post(
      '/api/v1/ai/generate',
      body: <String, Object?>{'prompt': prompt},
    );

    if (response is Map<String, Object?>) {
      final Object? data = response['data'];
      if (data is String) {
        return data;
      }
    }

    throw const ApiException(
      statusCode: 0,
      code: 'invalid_response',
      message: 'Backend returned an unexpected response.',
    );
  }
}
