class AiSession {
  const AiSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.scope,
    required this.scopeId,
    required this.messageCount,
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String scope;
  final String scopeId;
  final int messageCount;
}
