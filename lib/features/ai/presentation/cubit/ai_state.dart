class AiMessage {
  const AiMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isError = false,
  });

  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isError;
}

abstract class AiState {
  const AiState(this.messages);

  final List<AiMessage> messages;
}

class AiInitial extends AiState {
  const AiInitial(super.messages);
}

class AiLoading extends AiState {
  const AiLoading(super.messages);
}

class AiSessionLoading extends AiState {
  const AiSessionLoading(super.messages);
}

class AiLoaded extends AiState {
  const AiLoaded(super.messages);
}

class AiError extends AiState {
  const AiError(super.messages, this.error);

  final String error;
}
