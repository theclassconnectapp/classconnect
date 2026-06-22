import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../auth/domain/entities/app_user.dart';
import '../../domain/entities/ai_scope.dart';
import '../../domain/entities/ai_session.dart';
import '../../domain/repositories/ai_repository.dart';
import 'ai_chat_screen.dart';

class AiHistoryScreen extends StatelessWidget {
  const AiHistoryScreen({
    super.key,
    required this.aiRepository,
    required this.user,
    required this.scope,
    required this.scopeId,
  });

  final AiRepository aiRepository;
  final AppUser user;
  final AiScope scope;
  final String scopeId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI History'),
        actions: <Widget>[
          IconButton(
            tooltip: 'New chat',
            icon: const Icon(Icons.add),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => AiChatScreen(
                  aiRepository: aiRepository,
                  user: user,
                  scope: scope,
                  scopeId: scopeId,
                ),
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<AiSession>>(
        stream: aiRepository.streamSessions(uid: user.uid),
        builder: (BuildContext context, AsyncSnapshot<List<AiSession>> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }
          final List<AiSession> sessions = snapshot.data ?? <AiSession>[];
          if (sessions.isEmpty) {
            return const Center(child: Text('No previous conversations'));
          }

          return ListView.separated(
            itemCount: sessions.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (BuildContext context, int index) {
              final AiSession session = sessions[index];
              return ListTile(
                title: Text(
                  session.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${DateFormat.yMMMd().add_jm().format(session.updatedAt)} • ${session.messageCount} messages',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AiChatScreen(
                      aiRepository: aiRepository,
                      user: user,
                      scope: scope,
                      scopeId: scopeId,
                      sessionId: session.id,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
