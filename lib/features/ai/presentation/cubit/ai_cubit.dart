import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_exception.dart';
import '../../domain/repositories/ai_repository.dart';
import 'ai_state.dart';

const String _rateLimitMessage =
    "You've used all 5 daily AI questions. Come back in 24 hours!";

class AiCubit extends Cubit<AiState> {
  AiCubit({required AiRepository aiRepository})
    : _aiRepository = aiRepository,
      super(const AiInitial(<AiMessage>[]));

  final AiRepository _aiRepository;
  String? _sessionId;
  String? _uid;
  String? _scope;
  String? _scopeId;

  Future<void> startSession({
    required String uid,
    required String scope,
    required String scopeId,
  }) async {
    _uid = uid;
    _scope = scope;
    _scopeId = scopeId;
    _sessionId = null;
    emit(const AiInitial(<AiMessage>[]));
  }

  Future<void> loadSession({
    required String uid,
    required String sessionId,
  }) async {
    _uid = uid;
    _sessionId = sessionId;
    emit(const AiSessionLoading(<AiMessage>[]));
    try {
      final List<AiMessage> messages = await _aiRepository.loadMessages(
        uid: uid,
        sessionId: sessionId,
      );
      emit(AiLoaded(messages));
    } catch (_) {
      emit(const AiError(<AiMessage>[], 'Could not load conversation.'));
    }
  }

  Future<void> sendMessage(String prompt) async {
    final String trimmedPrompt = prompt.trim();
    if (trimmedPrompt.isEmpty || state is AiLoading) {
      return;
    }

    final List<AiMessage> withUserMessage = <AiMessage>[
      ...state.messages,
      AiMessage(text: trimmedPrompt, isUser: true, timestamp: DateTime.now()),
    ];
    final AiMessage userMessage = withUserMessage.last;
    emit(AiLoading(withUserMessage));

    try {
      final String? sessionId = await _ensureSession(trimmedPrompt);
      final String response = await _aiRepository.generateResponse(
        trimmedPrompt,
      );
      final AiMessage aiMessage = AiMessage(
        text: response,
        isUser: false,
        timestamp: DateTime.now(),
      );
      await _saveMessages(sessionId, <AiMessage>[userMessage, aiMessage]);
      emit(AiLoaded(<AiMessage>[...withUserMessage, aiMessage]));
    } on ApiException catch (error) {
      if (error.statusCode == 429 && error.code == 'RATE_LIMITED') {
        await _emitError(withUserMessage, _rateLimitMessage, userMessage);
        return;
      }

      await _emitError(withUserMessage, error.message, userMessage);
    } catch (_) {
      await _emitError(
        withUserMessage,
        'Could not generate a response.',
        userMessage,
      );
    }
  }

  Future<String?> _ensureSession(String firstMessage) async {
    if (_sessionId != null ||
        _uid == null ||
        _scope == null ||
        _scopeId == null) {
      return _sessionId;
    }
    try {
      _sessionId = await _aiRepository.createSession(
        uid: _uid!,
        scope: _scope!,
        scopeId: _scopeId!,
        firstMessage: firstMessage,
      );
    } catch (_) {
      return null;
    }
    return _sessionId;
  }

  Future<void> _saveMessages(
    String? sessionId,
    List<AiMessage> messages,
  ) async {
    final String? uid = _uid;
    if (uid == null || sessionId == null) return;
    for (final AiMessage message in messages) {
      try {
        await _aiRepository.saveMessage(
          uid: uid,
          sessionId: sessionId,
          message: message,
        );
      } catch (_) {
        return;
      }
    }
  }

  Future<void> _emitError(
    List<AiMessage> messages,
    String error,
    AiMessage userMessage,
  ) async {
    final String? sessionId = await _ensureSession(userMessage.text);
    final AiMessage errorMessage = AiMessage(
      text: error,
      isUser: false,
      timestamp: DateTime.now(),
      isError: true,
    );
    await _saveMessages(sessionId, <AiMessage>[userMessage, errorMessage]);
    emit(AiError(<AiMessage>[...messages, errorMessage], error));
  }
}
