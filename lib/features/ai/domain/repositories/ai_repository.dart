import '../../presentation/cubit/ai_state.dart';
import '../entities/ai_session.dart';

abstract class AiRepository {
  Future<String> generateResponse(String prompt);

  Future<String> createSession({
    required String uid,
    required String scope,
    required String scopeId,
    required String firstMessage,
  });

  Future<void> saveMessage({
    required String uid,
    required String sessionId,
    required AiMessage message,
  });

  Stream<List<AiSession>> streamSessions({required String uid});

  Future<List<AiMessage>> loadMessages({
    required String uid,
    required String sessionId,
  });
}
