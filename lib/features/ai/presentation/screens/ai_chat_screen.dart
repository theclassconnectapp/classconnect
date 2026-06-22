import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../auth/domain/entities/app_user.dart';
import '../../domain/entities/ai_scope.dart';
import '../../domain/repositories/ai_repository.dart';
import '../cubit/ai_cubit.dart';
import '../cubit/ai_state.dart';
import 'ai_history_screen.dart';

const String _rateLimitMessage =
    "You've used all 5 daily AI questions. Come back in 24 hours!";

class AiChatScreen extends StatelessWidget {
  const AiChatScreen({
    super.key,
    required this.aiRepository,
    required this.user,
    required this.scope,
    required this.scopeId,
    this.sessionId,
  });

  final AiRepository aiRepository;
  final AppUser user;
  final AiScope scope;
  final String scopeId;
  final String? sessionId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AiCubit>(
      create: (_) => AiCubit(aiRepository: aiRepository),
      child: _AiChatView(
        user: user,
        scope: scope,
        scopeId: scopeId,
        sessionId: sessionId,
        aiRepository: aiRepository,
      ),
    );
  }
}

class _AiChatView extends StatefulWidget {
  const _AiChatView({
    required this.user,
    required this.scope,
    required this.scopeId,
    required this.aiRepository,
    this.sessionId,
  });

  final AppUser user;
  final AiScope scope;
  final String scopeId;
  final AiRepository aiRepository;
  final String? sessionId;

  @override
  State<_AiChatView> createState() => _AiChatViewState();
}

class _AiChatViewState extends State<_AiChatView> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.sessionId != null) {
      context.read<AiCubit>().loadSession(
        uid: widget.user.uid,
        sessionId: widget.sessionId!,
      );
    } else {
      context.read<AiCubit>().startSession(
        uid: widget.user.uid,
        scope: widget.scope.name,
        scopeId: widget.scopeId,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send() {
    final String prompt = _controller.text.trim();
    if (prompt.isEmpty) {
      return;
    }
    context.read<AiCubit>().sendMessage(prompt);
    _controller.clear();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return BlocConsumer<AiCubit, AiState>(
      listener: (context, state) => _scrollToBottom(),
      builder: (context, state) {
        final bool loading = state is AiLoading;
        final bool loadingSession = state is AiSessionLoading;
        return Scaffold(
          appBar: AppBar(
            title: const Text('ClassConnect AI'),
            actions: <Widget>[
              IconButton(
                tooltip: 'AI History',
                icon: const Icon(Icons.history),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AiHistoryScreen(
                      aiRepository: widget.aiRepository,
                      user: widget.user,
                      scope: widget.scope,
                      scopeId: widget.scopeId,
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: <Widget>[
                Expanded(
                  child: loadingSession
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                          itemCount: state.messages.length + (loading ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == state.messages.length) {
                              return const _TypingIndicator();
                            }
                            return _MessageBubble(
                              message: state.messages[index],
                            );
                          },
                        ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    border: Border(
                      top: BorderSide(
                        color: colorScheme.outline.withValues(alpha: 0.18),
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            enabled: !loading && !loadingSession,
                            minLines: 1,
                            maxLines: 4,
                            textInputAction: TextInputAction.send,
                            decoration: const InputDecoration(
                              hintText: 'Ask ClassConnect AI',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            onSubmitted: loading || loadingSession
                                ? null
                                : (_) => _send(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          tooltip: 'Send',
                          onPressed: loading || loadingSession ? null : _send,
                          icon: const Icon(Icons.send),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final AiMessage message;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final bool isUser = message.isUser;
    final Color backgroundColor = message.isError
        ? colorScheme.errorContainer
        : isUser
        ? colorScheme.primary
        : colorScheme.surfaceContainerHighest;
    final Color foregroundColor = message.isError
        ? colorScheme.onErrorContainer
        : isUser
        ? colorScheme.onPrimary
        : colorScheme.onSurface;
    final bool isRateLimitError =
        message.isError && message.text == _rateLimitMessage;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: isUser
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: <Widget>[
              if (!isUser)
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: message.isError
                            ? colorScheme.error
                            : colorScheme.primary,
                        child: Text(
                          'CC',
                          style: TextStyle(
                            color: message.isError
                                ? colorScheme.onError
                                : colorScheme.onPrimary,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'CC AI',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ],
                  ),
                ),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: isUser || message.isError
                      ? _ErrorMessageContent(
                          message: message.text,
                          foregroundColor: foregroundColor,
                          showInfoIcon: isRateLimitError,
                        )
                      : MarkdownBody(
                          data: message.text,
                          selectable: true,
                          styleSheet:
                              MarkdownStyleSheet.fromTheme(
                                Theme.of(context),
                              ).copyWith(
                                p: TextStyle(color: foregroundColor),
                                listBullet: TextStyle(color: foregroundColor),
                              ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorMessageContent extends StatelessWidget {
  const _ErrorMessageContent({
    required this.message,
    required this.foregroundColor,
    required this.showInfoIcon,
  });

  final String message;
  final Color foregroundColor;
  final bool showInfoIcon;

  @override
  Widget build(BuildContext context) {
    if (!showInfoIcon) {
      return Text(message, style: TextStyle(color: foregroundColor));
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(Icons.info_outline, size: 16, color: foregroundColor),
        const SizedBox(width: 6),
        Flexible(
          child: Text(message, style: TextStyle(color: foregroundColor)),
        ),
      ],
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List<Widget>.generate(3, (int index) {
                    final double phase =
                        ((_controller.value + (index * 0.2)) % 1.0);
                    final double opacity = phase < 0.5
                        ? 0.35 + (phase * 1.3)
                        : 1.0 - ((phase - 0.5) * 1.3);
                    return Padding(
                      padding: EdgeInsets.only(right: index == 2 ? 0 : 4),
                      child: Opacity(
                        opacity: opacity.clamp(0.35, 1.0),
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: colorScheme.onSurfaceVariant,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
