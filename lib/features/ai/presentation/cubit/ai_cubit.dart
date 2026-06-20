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

  Future<void> sendMessage(String prompt) async {
    final String trimmedPrompt = prompt.trim();
    if (trimmedPrompt.isEmpty || state is AiLoading) {
      return;
    }

    final List<AiMessage> withUserMessage = <AiMessage>[
      ...state.messages,
      AiMessage(text: trimmedPrompt, isUser: true, timestamp: DateTime.now()),
    ];
    emit(AiLoading(withUserMessage));

    try {
      final String response = await _aiRepository.generateResponse(
        trimmedPrompt,
      );
      emit(
        AiLoaded(<AiMessage>[
          ...withUserMessage,
          AiMessage(text: response, isUser: false, timestamp: DateTime.now()),
        ]),
      );
    } on ApiException catch (error) {
      if (error.statusCode == 429 && error.code == 'RATE_LIMITED') {
        _emitError(withUserMessage, _rateLimitMessage);
        return;
      }

      _emitError(withUserMessage, error.message);
    } catch (_) {
      _emitError(withUserMessage, 'Could not generate a response.');
    }
  }

  void _emitError(List<AiMessage> messages, String error) {
    emit(
      AiError(<AiMessage>[
        ...messages,
        AiMessage(
          text: error,
          isUser: false,
          timestamp: DateTime.now(),
          isError: true,
        ),
      ], error),
    );
  }
}
