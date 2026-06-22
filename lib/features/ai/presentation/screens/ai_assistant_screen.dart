import 'package:flutter/material.dart';

import '../../../../core/di/injection_container.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../domain/entities/ai_scope.dart';
import '../../domain/repositories/ai_repository.dart';
import 'ai_chat_screen.dart';

class AiAssistantScreen extends StatelessWidget {
  const AiAssistantScreen({
    super.key,
    required this.user,
    required this.scope,
    required this.semesterId,
    this.groupId,
  });

  final AppUser user;
  final AiScope scope;
  final String semesterId;
  final String? groupId;

  @override
  Widget build(BuildContext context) {
    // scope/semesterId/groupId are reserved for future context-aware AI
    // (e.g. answering questions about a specific semester or group). For
    // now this redirects to the shared ClassConnect AI chat experience.
    return AiChatScreen(
      aiRepository: sl<AiRepository>(),
      user: user,
      scope: scope,
      scopeId: groupId ?? semesterId,
    );
  }
}
