import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../data/models/group_models.dart';
import '../../data/repositories/group_repository_impl.dart';
import '../../domain/repositories/group_repository.dart';
import 'package:classconnect/core/media/media_viewer_screens.dart';
import 'package:classconnect/core/media/upload_progress_sheet.dart';
import 'group_info_screen.dart';
import 'members_screen.dart';

class GroupChatScreen extends StatefulWidget {
  const GroupChatScreen({
    super.key,
    required this.groupId,
    required this.groupData,
    required this.user,
    required this.groupRepository,
    this.readOnly = false,
  });

  final String groupId;
  final Map<String, dynamic> groupData;
  final AppUser user;
  final GroupRepository groupRepository;
  final bool readOnly;

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _messageKeys = <String, GlobalKey>{};

  bool _searchMode = false;
  bool _isUploading = false;
  int _searchIndex = -1;
  List<String> _matchIds = <String>[];
  ChatMessage? _replyTo;
  String? _highlightMessageId;

  @override
  void initState() {
    super.initState();
    widget.groupRepository.markGroupSeen(
      groupId: widget.groupId,
      uid: widget.user.uid,
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool _isUrl(String text) =>
      text.startsWith('http://') || text.startsWith('https://');

  bool _isSuperAdmin(Map<String, dynamic> group) {
    final String dept = (group['dept'] as String?) ?? '';
    return widget.user.role == UserRole.hod && widget.user.dept == dept;
  }

  bool _isAdmin(Map<String, dynamic> group) {
    final List<dynamic> admins =
        (group['admins'] as List<dynamic>?) ?? <dynamic>[];
    return admins.contains(widget.user.uid) || _isSuperAdmin(group);
  }

  bool _isMuted(Map<String, dynamic> group) {
    final List<dynamic> muted =
        (group['mutedMembers'] as List<dynamic>?) ?? <dynamic>[];
    return muted.contains(widget.user.uid);
  }

  bool _isSubjectGroup(Map<String, dynamic> group) =>
      (group['type'] as String?) == GroupType.subject.id;

  bool _isMember(Map<String, dynamic> group) {
    final List<dynamic> memberIds =
        (group['memberIds'] as List<dynamic>?) ?? <dynamic>[];
    return memberIds.contains(widget.user.uid);
  }

  bool _canSend(Map<String, dynamic> group) {
    if (_isMuted(group)) return false;
    final bool onlyAdmins = group['onlyAdminsCanMessage'] as bool? ?? false;
    if (onlyAdmins && !_isAdmin(group)) return false;
    return true;
  }

  /// Opens media in-app: images/videos/pdfs get native in-app viewers,
  /// everything else falls back to download-and-open with OpenFilex.
  Future<void> _openMedia(
    String url, {
    String? fileType,
    String? fileName,
    MessageType? type,
  }) async {
    if (url.isEmpty) return;
    final String lowerUrl = url.toLowerCase();
    final String lowerType = (fileType ?? '').toLowerCase();

    final bool isImage =
        type == MessageType.image ||
        lowerType.contains('image') ||
        lowerUrl.contains('.png') ||
        lowerUrl.contains('.jpg') ||
        lowerUrl.contains('.jpeg') ||
        lowerUrl.contains('.webp');

    final bool isVideo =
        type == MessageType.video ||
        lowerType.contains('video') ||
        lowerUrl.contains('.mp4') ||
        lowerUrl.contains('.mov') ||
        lowerUrl.contains('.m4v');

    final bool isPdf =
        type == MessageType.pdf ||
        lowerType.contains('pdf') ||
        lowerUrl.contains('.pdf') ||
        lowerUrl.contains('application%2fpdf');

    if (!mounted) return;

    if (isImage) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ImageViewerScreen(imageUrl: url, title: fileName),
        ),
      );
      return;
    }

    if (isVideo) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => VideoViewerScreen(videoUrl: url, title: fileName),
        ),
      );
      return;
    }

    if (isPdf) {
      final String pdfUrl = url.contains('cloudinary.com')
          ? url
                .replaceFirst('/image/upload/', '/raw/upload/')
                .replaceFirst('/auto/upload/', '/raw/upload/')
          : url;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PdfViewerScreen(pdfUrl: pdfUrl, title: fileName),
        ),
      );
      return;
    }

    // Fallback for other file types: download and open with system viewer.
    await _downloadAndOpen(url, fileName: fileName);
  }

  Future<void> _downloadAndOpen(String url, {String? fileName}) async {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Opening file...')));
    try {
      final http.Response response = await http.get(Uri.parse(url));
      final Directory tempDir = await getTemporaryDirectory();
      final String resolvedName = (fileName != null && fileName.isNotEmpty)
          ? fileName
          : url.split('/').last.split('?').first;
      final File file = File('${tempDir.path}/$resolvedName');
      await file.writeAsBytes(response.bodyBytes);
      await OpenFilex.open(file.path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to open file: $e')));
    }
  }

  Future<void> _openLinkInText(String url) async {
    final Uri? uri = Uri.tryParse(url);
    if (uri == null) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open link')));
    }
  }

  Future<void> _sendText(Map<String, dynamic> group) async {
    if (!_canSend(group)) return;
    final String text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    // optimistic: mark as sending immediately (Firestore stream will replace this)
    // no local state needed — Firestore real-time update handles final status
    final Map<String, dynamic>? reply = _replyTo == null
        ? null
        : <String, dynamic>{
            'messageId': _replyTo!.id,
            'senderName': _replyTo!.senderName,
            'content': _replyTo!.content,
            'type': _replyTo!.type.id,
          };
    await widget.groupRepository.sendTextMessage(
      groupId: widget.groupId,
      sender: widget.user,
      text: text,
      replyTo: reply,
    );
    setState(() => _replyTo = null);
    _scrollToBottom();
    await widget.groupRepository.markGroupSeen(
      groupId: widget.groupId,
      uid: widget.user.uid,
    );
  }

  Future<void> _attachFile(Map<String, dynamic> group) async {
    if (!_canSend(group) || widget.user.role == UserRole.student) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot upload files in this group')),
      );
      return;
    }
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>[
        'png',
        'jpg',
        'jpeg',
        'webp',
        'pdf',
        'mp4',
        'mov',
        'm4v',
      ],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final PlatformFile file = result.files.first;
    final String lower = file.name.toLowerCase();

    final bool isPdf = lower.endsWith('.pdf');
    final bool isVideo =
        lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.m4v');

    final MessageType type = isPdf
        ? MessageType.pdf
        : (isVideo ? MessageType.video : MessageType.image);

    final String mimeType = isPdf
        ? 'application/pdf'
        : isVideo
        ? (lower.endsWith('.mov') ? 'video/quicktime' : 'video/mp4')
        : (lower.endsWith('.png')
              ? 'image/png'
              : (lower.endsWith('.webp') ? 'image/webp' : 'image/jpeg'));

    final Map<String, dynamic>? reply = _replyTo == null
        ? null
        : <String, dynamic>{
            'messageId': _replyTo!.id,
            'senderName': _replyTo!.senderName,
            'content': _replyTo!.content,
            'type': _replyTo!.type.id,
          };
    if (!mounted) return;
    setState(() => _isUploading = true);
    final StreamController<double> progressController =
        StreamController<double>();
    bool isCancelled = false;
    VoidCallback? cancelUpload;
    Future<void>? activeUpload;

    try {
      final bool? uploaded = await showModalBottomSheet<bool>(
        context: context,
        isDismissible: false,
        enableDrag: false,
        builder: (BuildContext context) {
          return UploadProgressSheet(
            fileName: file.name,
            fileSize: _formatFileSize(file.size),
            progressStream: progressController.stream,
            onCancel: () {
              isCancelled = true;
              cancelUpload?.call();
            },
            onRetry: () {
              isCancelled = false;
              cancelUpload = null;
              progressController.add(0);
            },
            uploadTask: () {
              activeUpload = widget.groupRepository.sendFileMessage(
                groupId: widget.groupId,
                sender: widget.user,
                type: type,
                fileName: file.name,
                mimeType: mimeType,
                fileSize: file.size,
                localPath: file.path,
                bytes: file.bytes,
                replyTo: reply,
                progressSink: progressController.sink,
                isCancelled: () => isCancelled,
                registerCancel: (void Function() cancel) {
                  cancelUpload = cancel;
                },
              );
              return activeUpload!;
            },
          );
        },
      );
      if (uploaded == true && mounted) {
        setState(() => _replyTo = null);
      }
    } finally {
      if (isCancelled) {
        await activeUpload?.catchError((Object _) {});
      }
      await progressController.close();
      if (mounted) setState(() => _isUploading = false);
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final double kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final double mb = kb / 1024;
    if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
    final double gb = mb / 1024;
    return '${gb.toStringAsFixed(1)} GB';
  }

  Future<void> _copy(ChatMessage message) async {
    final String value =
        message.type == MessageType.text || message.type == MessageType.link
        ? message.content
        : (message.fileUrl ?? message.content);
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _confirmDeleteGroup(
    BuildContext context,
    String groupId,
    String groupName,
  ) async {
    final TextEditingController confirmController = TextEditingController();
    try {
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) => StatefulBuilder(
          builder: (BuildContext dialogContext, StateSetter setDialogState) {
            final bool isValid = confirmController.text.trim() == 'DELETE';
            return AlertDialog(
              title: const Text('Delete Group'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'This will permanently delete "$groupName". This cannot be undone.',
                  ),
                  const SizedBox(height: 16),
                  const Text('Type DELETE to confirm:'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: confirmController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'DELETE',
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: isValid
                      ? () => Navigator.of(dialogContext).pop(true)
                      : null,
                  child: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            );
          },
        ),
      );

      if (confirmed == true && context.mounted) {
        try {
          await widget.groupRepository.deleteGroup(groupId: groupId);
          if (context.mounted) {
            Navigator.of(context).pop();
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to delete group: $e')),
            );
          }
        }
      }
    } finally {
      confirmController.dispose();
    }
  }

  Future<void> _forward(ChatMessage message) async {
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> groups =
        (await widget.groupRepository.streamGroupsForUser(widget.user).first)
            .docs;
    if (!mounted) return;
    final String? target = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: groups
              .where(
                (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                    d.id != widget.groupId,
              )
              .map((QueryDocumentSnapshot<Map<String, dynamic>> d) {
                final String name = (d.data()['name'] as String?) ?? d.id;
                return ListTile(
                  title: Text(name),
                  onTap: () => Navigator.of(context).pop(d.id),
                );
              })
              .toList(),
        ),
      ),
    );
    if (target == null) return;
    await widget.groupRepository.forwardMessage(
      sourceGroupId: widget.groupId,
      messageId: message.id,
      targetGroupId: target,
      sender: widget.user,
    );
  }

  Future<void> _messageActions(
    ChatMessage message,
    Map<String, dynamic> group,
  ) async {
    if (message.isDeleted) return;
    if (widget.readOnly) return;
    final bool canDelete =
        _isSuperAdmin(group) || message.uid == widget.user.uid;
    final bool canPin = _isAdmin(group);
    final String? action = await showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final String emoji in ['👍', '❤️', '😂', '😮'])
              ListTile(
                title: Text('React $emoji'),
                onTap: () => Navigator.of(context).pop('react:$emoji'),
              ),
            ListTile(
              title: const Text('Reply'),
              onTap: () => Navigator.of(context).pop('reply'),
            ),
            ListTile(
              title: const Text('Forward'),
              onTap: () => Navigator.of(context).pop('forward'),
            ),
            ListTile(
              title: const Text('Copy'),
              onTap: () => Navigator.of(context).pop('copy'),
            ),
            if (message.status == 'failed')
              ListTile(
                leading: const Icon(
                  Icons.refresh_rounded,
                  color: Colors.redAccent,
                ),
                title: const Text('Retry send'),
                onTap: () => Navigator.of(context).pop('retry'),
              ),
            if (canPin)
              ListTile(
                title: const Text('Pin'),
                onTap: () => Navigator.of(context).pop('pin'),
              ),
            if (canDelete)
              ListTile(
                title: const Text('Delete message'),
                onTap: () => Navigator.of(context).pop('delete'),
              ),
          ],
        ),
      ),
    );
    if (action == null) return;
    if (!mounted) return;
    if (action.startsWith('react:')) {
      try {
        await widget.groupRepository.reactToMessage(
          groupId: widget.groupId,
          messageId: message.id,
          uid: widget.user.uid,
          reaction: action.replaceFirst('react:', ''),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to react. Please try again.')),
        );
      }
      return;
    }
    if (action == 'reply') {
      setState(() => _replyTo = message);
      return;
    }
    if (action == 'forward') {
      await _forward(message);
      return;
    }
    if (action == 'copy') {
      await _copy(message);
      return;
    }
    if (action == 'retry') {
      // re-send by writing back to Firestore — status field will reset
      await widget.groupRepository.sendTextMessage(
        groupId: widget.groupId,
        sender: widget.user,
        text: message.content,
        replyTo: message.replyTo,
      );
      return;
    }
    if (action == 'pin') {
      try {
        await widget.groupRepository.pinMessage(
          groupId: widget.groupId,
          messageId: message.id,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Message pinned.')));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to pin message. Please try again.'),
          ),
        );
      }
      return;
    }
    if (action == 'delete') {
      try {
        await widget.groupRepository.deleteMessage(
          groupId: widget.groupId,
          messageId: message.id,
          deletedByUid: widget.user.uid,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Message deleted.')));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete message. Please try again.'),
          ),
        );
      }
    }
  }

  void _runSearch(List<ChatMessage> messages) {
    final String query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      _matchIds = <String>[];
      _searchIndex = -1;
      return;
    }
    final List<String> hits = messages
        .where((ChatMessage m) => !m.isDeleted)
        .where((ChatMessage m) => m.content.toLowerCase().contains(query))
        .map((ChatMessage m) => m.id)
        .toList();
    _matchIds = hits;
    if (_searchIndex >= hits.length) {
      _searchIndex = hits.isEmpty ? -1 : 0;
    }
    if (_searchIndex == -1 && hits.isNotEmpty) {
      _searchIndex = 0;
    }
    if (hits.isNotEmpty) {
      if (_highlightMessageId != hits[_searchIndex]) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToMessage(hits[_searchIndex]);
        });
      }
    }
  }

  void _moveSearch(int delta) {
    if (_matchIds.isEmpty) return;
    setState(() {
      _searchIndex = (_searchIndex + delta) % _matchIds.length;
      if (_searchIndex < 0) {
        _searchIndex = _matchIds.length - 1;
      }
    });
    _scrollToMessage(_matchIds[_searchIndex]);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _scrollToMessage(String messageId) {
    final GlobalKey? key = _messageKeys[messageId];
    final BuildContext? ctx = key?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 280),
      alignment: 0.2,
    );
    setState(() => _highlightMessageId = messageId);
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      if (_highlightMessageId == messageId) {
        setState(() => _highlightMessageId = null);
      }
    });
  }

  Widget _attachmentPreview(ChatMessage m) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final String label = m.fileName ?? m.content;
    switch (m.type) {
      case MessageType.image:
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: m.fileUrl ?? '',
            width: 220,
            height: 160,
            fit: BoxFit.cover,
            errorWidget: (_, _, _) => Container(
              width: 220,
              height: 160,
              color: colorScheme.surfaceContainerHighest,
              child: const Icon(Icons.broken_image),
            ),
          ),
        );
      case MessageType.video:
        return Container(
          width: 220,
          height: 160,
          decoration: BoxDecoration(
            color: colorScheme.onSurface.withAlpha(222),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Icon(
              Icons.play_circle_fill,
              color: colorScheme.onSurface,
              size: 48,
            ),
          ),
        );
      case MessageType.pdf:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.picture_as_pdf, size: 18),
            const SizedBox(width: 6),
            Flexible(child: Text(label)),
          ],
        );
      default:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.insert_drive_file, size: 18),
            const SizedBox(width: 6),
            Flexible(child: Text(label)),
          ],
        );
    }
  }

  Widget _messageBubble(ChatMessage m, Map<String, dynamic> group) {
    if (m.type == MessageType.system) {
      final ColorScheme colorScheme = Theme.of(context).colorScheme;
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            m.content,
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurface.withAlpha(138),
            ),
          ),
        ),
      );
    }
    final bool mine = m.uid == widget.user.uid;
    final bool highlighted = _highlightMessageId == m.id;
    final String query = _searchController.text.trim();
    final bool queryHit =
        query.isNotEmpty &&
        m.content.toLowerCase().contains(query.toLowerCase());
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final Color base = m.isDeleted
        ? colorScheme.surfaceContainerHigh.withAlpha(120)
        : mine
        ? colorScheme.primaryContainer
        : colorScheme.surfaceContainerHighest;
    final Color color = highlighted ? colorScheme.secondaryContainer : base;
    final Color messageTextColor = highlighted
        ? colorScheme.onSecondaryContainer
        : mine
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurface;
    return Dismissible(
      key: ValueKey<String>('dismiss_${m.id}'),
      direction: DismissDirection.startToEnd,
      confirmDismiss: (_) async {
        if (m.isDeleted) return false;
        setState(() => _replyTo = m);
        return false;
      },
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 12),
        child: const Icon(Icons.reply),
      ),
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          key: _messageKeys.putIfAbsent(m.id, () => GlobalKey()),
          margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          constraints: const BoxConstraints(maxWidth: 320),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(mine ? 16 : 4),
              bottomRight: Radius.circular(mine ? 4 : 16),
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withAlpha(15),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: InkWell(
            onLongPress: () => _messageActions(m, group),
            child: Column(
              crossAxisAlignment: mine
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: <Widget>[
                if (m.isForwarded)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.forward, size: 12, color: messageTextColor),
                      const SizedBox(width: 4),
                      Text(
                        'Forwarded',
                        style: TextStyle(fontSize: 11, color: messageTextColor),
                      ),
                    ],
                  ),
                if (!mine)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      UserAvatar(
                        name: m.senderName,
                        photoUrl: m.senderPhoto,
                        radius: 10,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        m.senderName,
                        style: TextStyle(
                          color: messageTextColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                if (m.replyTo != null)
                  InkWell(
                    onTap: () {
                      final String? id = m.replyTo!['messageId'] as String?;
                      if (id != null) _scrollToMessage(id);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(top: 4, bottom: 4),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: colorScheme.onSurface.withAlpha(31),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            (m.replyTo!['senderName'] as String?) ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            (m.replyTo!['content'] as String?) ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                if (m.isDeleted)
                  Text(
                    'This message was deleted',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: colorScheme.onSurface.withAlpha(138),
                    ),
                  )
                else if (m.type == MessageType.text ||
                    m.type == MessageType.link)
                  GestureDetector(
                    onTap: _isUrl(m.content)
                        ? () => _openLinkInText(m.content)
                        : null,
                    child: Text(
                      m.content,
                      style: TextStyle(
                        fontWeight: queryHit
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: _isUrl(m.content)
                            ? colorScheme.primary
                            : messageTextColor,
                        decoration: _isUrl(m.content)
                            ? TextDecoration.underline
                            : null,
                      ),
                    ),
                  )
                else
                  GestureDetector(
                    onTap: m.fileUrl == null
                        ? null
                        : () => _openMedia(
                            m.fileUrl!,
                            fileType: m.fileType,
                            fileName: m.fileName,
                            type: m.type,
                          ),
                    child: _attachmentPreview(m),
                  ),
                if (!m.isDeleted && m.reactions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Wrap(
                      spacing: 4,
                      children: _reactionCounts(m.reactions).entries
                          .map(
                            (MapEntry<String, int> e) => Chip(
                              visualDensity: VisualDensity.compact,
                              label: Text('${e.key} ${e.value}'),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat.Hm().format(m.timestamp ?? DateTime.now()),
                      style: TextStyle(
                        fontSize: 10,
                        color: messageTextColor.withAlpha(153),
                      ),
                    ),
                    if (mine) ...[
                      const SizedBox(width: 3),
                      _MessageStatusIcon(
                        status: m.status,
                        color: messageTextColor.withAlpha(153),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Map<String, int> _reactionCounts(Map<String, dynamic> reactions) {
    final Map<String, int> counts = <String, int>{};
    for (final dynamic v in reactions.values) {
      final String k = v?.toString() ?? '';
      if (k.isEmpty) continue;
      counts[k] = (counts[k] ?? 0) + 1;
    }
    return counts;
  }

  Widget _dateChip(DateTime day) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          DateFormat.yMMMd().format(day),
          style: TextStyle(color: colorScheme.onSurface.withAlpha(153)),
        ),
      ),
    );
  }

  List<Widget> _messageWidgets(
    List<ChatMessage> messages,
    Map<String, dynamic> group,
  ) {
    DateTime? lastDay;
    final List<Widget> out = <Widget>[];
    for (final ChatMessage m in messages) {
      final DateTime ts = (m.timestamp ?? DateTime.now()).toLocal();
      final DateTime day = DateTime(ts.year, ts.month, ts.day);
      if (lastDay == null ||
          day.year != lastDay.year ||
          day.month != lastDay.month ||
          day.day != lastDay.day) {
        out.add(_dateChip(day));
        lastDay = day;
      }
      out.add(_messageBubble(m, group));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: widget.groupRepository.streamGroupDoc(widget.groupId),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> groupSnapshot,
          ) {
            final Map<String, dynamic> group =
                groupSnapshot.data?.data() ?? widget.groupData;
            final String title = (group['name'] as String?) ?? 'Group';
            final String? photoUrl = group['photoUrl'] as String?;
            final bool canSend = _canSend(group);
            final bool isAdmin = _isAdmin(group);
            final String? pinnedMessageId = group['pinnedMessageId'] as String?;
            final bool showJoinGate =
                _isSubjectGroup(group) && !_isMember(group);

            return DefaultTabController(
              length: 2,
              child: Scaffold(
                appBar: AppBar(
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                  iconTheme: IconThemeData(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  title: _searchMode
                      ? TextField(
                          controller: _searchController,
                          autofocus: true,
                          decoration: const InputDecoration(
                            hintText: 'Search messages',
                            border: InputBorder.none,
                          ),
                          onChanged: (_) => setState(() {}),
                        )
                      : Row(
                          children: <Widget>[
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: colorScheme.primary,
                              backgroundImage:
                                  photoUrl != null && photoUrl.isNotEmpty
                                  ? NetworkImage(photoUrl)
                                  : null,
                              child: photoUrl == null || photoUrl.isEmpty
                                  ? Text(
                                      title.isEmpty
                                          ? '?'
                                          : title[0].toUpperCase(),
                                      style: TextStyle(
                                        color: colorScheme.onPrimary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                title,
                                style: TextStyle(
                                  color: colorScheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                  bottom: TabBar(
                    labelColor: Theme.of(context).colorScheme.onSurface,
                    unselectedLabelColor: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.60),
                    indicatorColor: Theme.of(context).colorScheme.primary,
                    dividerColor: Theme.of(context).colorScheme.outlineVariant,
                    tabs: const <Tab>[
                      Tab(text: 'Chat'),
                      Tab(text: 'Files'),
                    ],
                  ),
                  actions: <Widget>[
                    if (_searchMode)
                      IconButton(
                        onPressed: () => _moveSearch(-1),
                        icon: const Icon(Icons.keyboard_arrow_up),
                      ),
                    if (_searchMode)
                      IconButton(
                        onPressed: () => _moveSearch(1),
                        icon: const Icon(Icons.keyboard_arrow_down),
                      ),
                    if (_searchMode)
                      Center(
                        child: Text(
                          _matchIds.isEmpty
                              ? '0'
                              : '${_searchIndex + 1} of ${_matchIds.length}',
                        ),
                      ),
                    IconButton(
                      icon: Icon(_searchMode ? Icons.close : Icons.search),
                      onPressed: () {
                        setState(() {
                          _searchMode = !_searchMode;
                          if (!_searchMode) {
                            _searchController.clear();
                            _matchIds = <String>[];
                            _searchIndex = -1;
                          }
                        });
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.info_outline),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => GroupInfoScreen(
                              groupId: widget.groupId,
                              groupData: group,
                              currentUser: widget.user,
                              groupRepository: widget.groupRepository,
                            ),
                          ),
                        );
                      },
                    ),
                    PopupMenuButton<String>(
                      onSelected: (String action) {
                        if (action == 'members') {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => MembersScreen(
                                groupId: widget.groupId,
                                groupTitle: title,
                                groupRepository: widget.groupRepository,
                                currentUser: widget.user,
                                groupData: group,
                              ),
                            ),
                          );
                        } else if (action == 'delete') {
                          _confirmDeleteGroup(
                            context,
                            widget.groupId,
                            group['name'] as String? ?? 'this group',
                          );
                        }
                      },
                      itemBuilder: (_) => <PopupMenuEntry<String>>[
                        const PopupMenuItem<String>(
                          value: 'members',
                          child: Text('Members'),
                        ),
                        if (canDeleteGroup(
                          groupData: group,
                          currentUser: widget.user,
                        ))
                          const PopupMenuItem<String>(
                            value: 'delete',
                            child: Text(
                              'Delete Group',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                body: Stack(
                  children: <Widget>[
                    AbsorbPointer(
                      absorbing: showJoinGate,
                      child: ImageFiltered(
                        imageFilter: ui.ImageFilter.blur(
                          sigmaX: showJoinGate ? 6 : 0,
                          sigmaY: showJoinGate ? 6 : 0,
                        ),
                        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: widget.groupRepository.streamMessages(
                            widget.groupId,
                          ),
                          builder:
                              (
                                BuildContext context,
                                AsyncSnapshot<
                                  QuerySnapshot<Map<String, dynamic>>
                                >
                                snapshot,
                              ) {
                                final List<ChatMessage> messages =
                                    (snapshot.data?.docs ??
                                            <
                                              QueryDocumentSnapshot<
                                                Map<String, dynamic>
                                              >
                                            >[])
                                        .map(ChatMessage.fromDoc)
                                        .toList();
                                if (_searchMode) {
                                  _runSearch(messages);
                                }
                                _scrollToBottom();

                                ChatMessage? pinned;
                                if (pinnedMessageId != null) {
                                  for (final ChatMessage m in messages) {
                                    if (m.id == pinnedMessageId) {
                                      pinned = m;
                                      break;
                                    }
                                  }
                                }

                                return TabBarView(
                                  children: <Widget>[
                                    Column(
                                      children: <Widget>[
                                        if (pinned != null)
                                          Material(
                                            color: colorScheme
                                                .secondaryContainer
                                                .withAlpha(51),
                                            child: ListTile(
                                              dense: true,
                                              title: Text(
                                                'Pinned • ${pinned.senderName}: ${pinned.content.length > 40 ? '${pinned.content.substring(0, 40)}...' : pinned.content}',
                                              ),
                                              onTap: () =>
                                                  _scrollToMessage(pinned!.id),
                                              trailing: isAdmin
                                                  ? IconButton(
                                                      icon: const Icon(
                                                        Icons.close,
                                                      ),
                                                      onPressed: () => widget
                                                          .groupRepository
                                                          .pinMessage(
                                                            groupId:
                                                                widget.groupId,
                                                            messageId: null,
                                                          ),
                                                    )
                                                  : null,
                                            ),
                                          ),
                                        if (!canSend)
                                          Container(
                                            width: double.infinity,
                                            color: colorScheme.primary
                                                .withAlpha(51),
                                            padding: const EdgeInsets.all(8),
                                            child: Text(
                                              _isMuted(group)
                                                  ? 'You are muted'
                                                  : 'Only admins can send messages',
                                            ),
                                          ),
                                        Expanded(
                                          child: ListView(
                                            controller: _scrollController,
                                            padding: const EdgeInsets.all(12),
                                            children: _messageWidgets(
                                              messages,
                                              group,
                                            ),
                                          ),
                                        ),
                                        if (_replyTo != null)
                                          Container(
                                            color: colorScheme
                                                .surfaceContainerHighest,
                                            padding: const EdgeInsets.all(8),
                                            child: Row(
                                              children: <Widget>[
                                                Expanded(
                                                  child: Text(
                                                    'Replying to ${_replyTo!.senderName}: ${_replyTo!.content}',
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                IconButton(
                                                  onPressed: () => setState(
                                                    () => _replyTo = null,
                                                  ),
                                                  icon: const Icon(Icons.close),
                                                ),
                                              ],
                                            ),
                                          ),
                                        if (widget.readOnly)
                                          Container(
                                            width: double.infinity,
                                            color: colorScheme
                                                .surfaceContainerHighest,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 12,
                                              horizontal: 16,
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.archive_outlined,
                                                  size: 16,
                                                  color: colorScheme.onSurface
                                                      .withAlpha(153),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'Archived semester — read only',
                                                  style: TextStyle(
                                                    color: colorScheme.onSurface
                                                        .withAlpha(153),
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                        else
                                          SafeArea(
                                            top: false,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.fromLTRB(
                                                    8,
                                                    4,
                                                    8,
                                                    8,
                                                  ),
                                              child: Row(
                                                children: <Widget>[
                                                  IconButton(
                                                    onPressed: _isUploading
                                                        ? null
                                                        : (canSend &&
                                                                  widget
                                                                          .user
                                                                          .role !=
                                                                      UserRole
                                                                          .student
                                                              ? () =>
                                                                    _attachFile(
                                                                      group,
                                                                    )
                                                              : null),
                                                    icon: _isUploading
                                                        ? const SizedBox(
                                                            width: 20,
                                                            height: 20,
                                                            child:
                                                                CircularProgressIndicator(
                                                                  strokeWidth:
                                                                      2,
                                                                ),
                                                          )
                                                        : const Icon(
                                                            Icons.attach_file,
                                                          ),
                                                  ),
                                                  Expanded(
                                                    child: TextField(
                                                      controller:
                                                          _textController,
                                                      enabled: canSend,
                                                      decoration:
                                                          const InputDecoration(
                                                            hintText:
                                                                'Type a message',
                                                            border:
                                                                OutlineInputBorder(),
                                                          ),
                                                    ),
                                                  ),
                                                  IconButton(
                                                    onPressed: canSend
                                                        ? () => _sendText(group)
                                                        : null,
                                                    icon: const Icon(
                                                      Icons.send,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    StreamBuilder<
                                      QuerySnapshot<Map<String, dynamic>>
                                    >(
                                      stream: widget.groupRepository
                                          .streamFiles(widget.groupId),
                                      builder:
                                          (
                                            BuildContext context,
                                            AsyncSnapshot<
                                              QuerySnapshot<
                                                Map<String, dynamic>
                                              >
                                            >
                                            fileSnap,
                                          ) {
                                            final List<
                                              QueryDocumentSnapshot<
                                                Map<String, dynamic>
                                              >
                                            >
                                            docs =
                                                fileSnap.data?.docs ??
                                                <
                                                  QueryDocumentSnapshot<
                                                    Map<String, dynamic>
                                                  >
                                                >[];
                                            if (docs.isEmpty) {
                                              return Center(
                                                child: Text(
                                                  'No files shared yet.',
                                                  style: TextStyle(
                                                    color: Theme.of(
                                                      context,
                                                    ).colorScheme.onSurface,
                                                  ),
                                                ),
                                              );
                                            }
                                            return GridView.builder(
                                              padding: const EdgeInsets.all(12),
                                              gridDelegate:
                                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                                    crossAxisCount: 2,
                                                    mainAxisSpacing: 10,
                                                    crossAxisSpacing: 10,
                                                    childAspectRatio: 1.4,
                                                  ),
                                              itemCount: docs.length,
                                              itemBuilder: (_, int index) {
                                                final Map<String, dynamic>
                                                file = docs[index].data();
                                                final String name =
                                                    (file['fileName']
                                                        as String?) ??
                                                    'File';
                                                final String fileType =
                                                    (file['fileType']
                                                        as String?) ??
                                                    '';
                                                return Card(
                                                  child: InkWell(
                                                    onTap: () => _openMedia(
                                                      (file['fileUrl']
                                                              as String?) ??
                                                          '',
                                                      fileType: fileType,
                                                      fileName: name,
                                                    ),
                                                    onLongPress: () async {
                                                      final String?
                                                      action = await showModalBottomSheet<String>(
                                                        context: context,
                                                        builder: (_) => SafeArea(
                                                          child: Column(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: <Widget>[
                                                              ListTile(
                                                                title:
                                                                    const Text(
                                                                      'Copy',
                                                                    ),
                                                                onTap: () =>
                                                                    Navigator.of(
                                                                      context,
                                                                    ).pop(
                                                                      'copy',
                                                                    ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      );
                                                      if (action == 'copy') {
                                                        await Clipboard.setData(
                                                          ClipboardData(
                                                            text:
                                                                (file['fileUrl']
                                                                    as String?) ??
                                                                '',
                                                          ),
                                                        );
                                                        if (!context.mounted) {
                                                          return;
                                                        }
                                                        ScaffoldMessenger.of(
                                                          context,
                                                        ).showSnackBar(
                                                          const SnackBar(
                                                            content: Text(
                                                              'Copied to clipboard',
                                                            ),
                                                          ),
                                                        );
                                                      }
                                                    },
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            12,
                                                          ),
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        children: <Widget>[
                                                          Icon(
                                                            fileType.contains(
                                                                  'image',
                                                                )
                                                                ? Icons.image
                                                                : fileType
                                                                      .contains(
                                                                        'video',
                                                                      )
                                                                ? Icons.videocam
                                                                : Icons
                                                                      .picture_as_pdf,
                                                            size: 28,
                                                            color:
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .colorScheme
                                                                    .onSurface,
                                                          ),
                                                          const SizedBox(
                                                            height: 8,
                                                          ),
                                                          Text(
                                                            name,
                                                            maxLines: 2,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style: TextStyle(
                                                              color:
                                                                  Theme.of(
                                                                        context,
                                                                      )
                                                                      .colorScheme
                                                                      .onSurface,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                            );
                                          },
                                    ),
                                  ],
                                );
                              },
                        ),
                      ),
                    ),
                    if (showJoinGate)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black.withAlpha(40),
                          child: Center(
                            child: Card(
                              margin: const EdgeInsets.all(32),
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Icon(
                                      Icons.group_add_rounded,
                                      size: 40,
                                      color: colorScheme.primary,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Join $title to view messages',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    FilledButton.icon(
                                      icon: const Icon(Icons.login),
                                      label: const Text('Join Group'),
                                      onPressed: () async {
                                        await widget.groupRepository.addMember(
                                          groupId: widget.groupId,
                                          user: widget.user,
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
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

/// Animated message status indicator.
/// Transitions smoothly between sending → sent → failed states.
class _MessageStatusIcon extends StatelessWidget {
  const _MessageStatusIcon({required this.status, required this.color});

  final String status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) => ScaleTransition(
        scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: _icon(status, color),
    );
  }

  Widget _icon(String status, Color color) {
    switch (status) {
      case 'sending':
        return SizedBox(
          key: const ValueKey('sending'),
          width: 11,
          height: 11,
          child: CircularProgressIndicator(strokeWidth: 1.5, color: color),
        );
      case 'failed':
        return Icon(
          key: const ValueKey('failed'),
          Icons.error_outline_rounded,
          size: 12,
          color: Colors.redAccent,
        );
      default: // 'sent'
        return Icon(
          key: const ValueKey('sent'),
          Icons.check_rounded,
          size: 12,
          color: color,
        );
    }
  }
}
