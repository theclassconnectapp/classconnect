import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/app_user.dart';
import '../../models/group_models.dart';
import '../../models/user_role.dart';
import '../../services/group_repository.dart';
import '../widgets/user_avatar.dart';
import 'group_info_screen.dart';
import 'members_screen.dart';

class GroupChatScreen extends StatefulWidget {
  const GroupChatScreen({
    super.key,
    required this.groupId,
    required this.groupData,
    required this.user,
    required this.groupRepository,
  });

  final String groupId;
  final Map<String, dynamic> groupData;
  final AppUser user;
  final GroupRepository groupRepository;

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _messageKeys = <String, GlobalKey>{};

  bool _searchMode = false;
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
    final List<dynamic> admins = (group['admins'] as List<dynamic>?) ?? <dynamic>[];
    return admins.contains(widget.user.uid) || _isSuperAdmin(group);
  }

  bool _isMuted(Map<String, dynamic> group) {
    final List<dynamic> muted = (group['mutedMembers'] as List<dynamic>?) ?? <dynamic>[];
    return muted.contains(widget.user.uid);
  }

  bool _canSend(Map<String, dynamic> group) {
    if (_isMuted(group)) {
      return false;
    }
    final bool onlyAdmins = group['onlyAdminsCanMessage'] as bool? ?? false;
    if (onlyAdmins && !_isAdmin(group)) {
      return false;
    }
    return true;
  }

  Future<void> _openUrl(String url) async {
    final Uri? uri = Uri.tryParse(url);
    if (uri == null || !(uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https'))) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot open local/non-http file: $url')),
      );
      return;
    }
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open link/file')),
      );
    }
  }

  Future<void> _sendText(Map<String, dynamic> group) async {
    if (!_canSend(group)) return;
    final String text = _textController.text.trim();
    if (text.isEmpty) {
      return;
    }
    _textController.clear();
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
      allowedExtensions: <String>['png', 'jpg', 'jpeg', 'pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return;
    }
    final PlatformFile file = result.files.first;
    final String lower = file.name.toLowerCase();
    final bool isPdf = lower.endsWith('.pdf');
    final MessageType type = isPdf ? MessageType.pdf : MessageType.image;
    final String mimeType = isPdf
        ? 'application/pdf'
        : (lower.endsWith('.png') ? 'image/png' : 'image/jpeg');
    final Map<String, dynamic>? reply = _replyTo == null
        ? null
        : <String, dynamic>{
            'messageId': _replyTo!.id,
            'senderName': _replyTo!.senderName,
            'content': _replyTo!.content,
            'type': _replyTo!.type.id,
          };
    await widget.groupRepository.sendFileMessage(
      groupId: widget.groupId,
      sender: widget.user,
      type: type,
      fileName: file.name,
      mimeType: mimeType,
      fileSize: file.size,
      localPath: file.path,
      bytes: file.bytes,
      replyTo: reply,
    );
    setState(() => _replyTo = null);
  }

  Future<void> _copy(ChatMessage message) async {
    final String value = message.type == MessageType.text || message.type == MessageType.link
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

  Future<void> _forward(ChatMessage message) async {
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> groups =
        (await widget.groupRepository.streamGroupsForUser(widget.user).first).docs;
    if (!mounted) return;
    final String? target = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: groups
              .where((QueryDocumentSnapshot<Map<String, dynamic>> d) => d.id != widget.groupId)
              .map((QueryDocumentSnapshot<Map<String, dynamic>> d) {
            final String name = (d.data()['name'] as String?) ?? d.id;
            return ListTile(
              title: Text(name),
              onTap: () => Navigator.of(context).pop(d.id),
            );
          }).toList(),
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

  Future<void> _messageActions(ChatMessage message, Map<String, dynamic> group) async {
    final bool canDelete = _isSuperAdmin(group) || message.uid == widget.user.uid;
    final bool canPin = _isAdmin(group);
    final String? action = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final String emoji in <String>['👍', '❤️', '😂', '😮'])
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
    if (action.startsWith('react:')) {
      await widget.groupRepository.reactToMessage(
        groupId: widget.groupId,
        messageId: message.id,
        uid: widget.user.uid,
        reaction: action.replaceFirst('react:', ''),
      );
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
    if (action == 'pin') {
      await widget.groupRepository.pinMessage(groupId: widget.groupId, messageId: message.id);
      return;
    }
    if (action == 'delete') {
      await widget.groupRepository.deleteMessage(
        groupId: widget.groupId,
        messageId: message.id,
        deletedByUid: widget.user.uid,
      );
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

  Widget _messageBubble(ChatMessage m, Map<String, dynamic> group) {
    final bool mine = m.uid == widget.user.uid;
    final bool highlighted = _highlightMessageId == m.id;
    final String query = _searchController.text.trim();
    final bool queryHit =
        query.isNotEmpty && m.content.toLowerCase().contains(query.toLowerCase());
    final Color base = mine ? Colors.green.shade200 : Colors.grey.shade200;
    final Color color = highlighted ? Colors.yellow.shade200 : base;
    return Dismissible(
      key: ValueKey<String>('dismiss_${m.id}'),
      direction: DismissDirection.startToEnd,
      confirmDismiss: (_) async {
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
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(10),
          constraints: const BoxConstraints(maxWidth: 320),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onLongPress: () => _messageActions(m, group),
            child: Column(
              crossAxisAlignment:
                  mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: <Widget>[
                if (m.isForwarded)
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.forward, size: 12),
                      SizedBox(width: 4),
                      Text('Forwarded', style: TextStyle(fontSize: 11)),
                    ],
                  ),
                if (!mine)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      UserAvatar(name: m.senderName, photoUrl: m.senderPhoto, radius: 10),
                      const SizedBox(width: 6),
                      Text(
                        m.senderName,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
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
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            (m.replyTo!['senderName'] as String?) ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
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
                  const Text(
                    'This message was deleted',
                    style: TextStyle(fontStyle: FontStyle.italic, color: Colors.black54),
                  )
                else if (m.type == MessageType.text || m.type == MessageType.link)
                  GestureDetector(
                    onTap: _isUrl(m.content) ? () => _openUrl(m.content) : null,
                    child: Text(
                      m.content,
                      style: TextStyle(
                        fontWeight: queryHit ? FontWeight.bold : FontWeight.normal,
                        color: _isUrl(m.content) ? Colors.blue : null,
                        decoration: _isUrl(m.content) ? TextDecoration.underline : null,
                      ),
                    ),
                  )
                else
                  GestureDetector(
                    onTap: m.fileUrl == null ? null : () => _openUrl(m.fileUrl!),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          m.type == MessageType.image
                              ? Icons.image
                              : Icons.picture_as_pdf,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Flexible(child: Text(m.fileName ?? m.content)),
                      ],
                    ),
                  ),
                if (m.reactions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Wrap(
                      spacing: 4,
                      children: _reactionCounts(m.reactions).entries
                          .map((MapEntry<String, int> e) => Chip(
                                visualDensity: VisualDensity.compact,
                                label: Text('${e.key} ${e.value}'),
                              ))
                          .toList(),
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  DateFormat.Hm().format(m.timestamp ?? DateTime.now()),
                  style: const TextStyle(fontSize: 10),
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
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.blueGrey.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(DateFormat.yMMMd().format(day)),
      ),
    );
  }

  List<Widget> _messageWidgets(List<ChatMessage> messages, Map<String, dynamic> group) {
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
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: widget.groupRepository.streamGroupDoc(widget.groupId),
      builder: (BuildContext context,
          AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> groupSnapshot) {
        final Map<String, dynamic> group = groupSnapshot.data?.data() ?? widget.groupData;
        final String title = (group['name'] as String?) ?? 'Group';
        final String? photoUrl = group['photoUrl'] as String?;
        final bool canSend = _canSend(group);
        final bool isAdmin = _isAdmin(group);
        final String? pinnedMessageId = group['pinnedMessageId'] as String?;

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
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
                          backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                              ? NetworkImage(photoUrl)
                              : null,
                          child: photoUrl == null || photoUrl.isEmpty
                              ? Text(title.isEmpty ? '?' : title[0].toUpperCase())
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(title)),
                      ],
                    ),
              bottom: const TabBar(tabs: <Tab>[Tab(text: 'Chat'), Tab(text: 'Files')]),
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
                    }
                  },
                  itemBuilder: (_) => const <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(value: 'members', child: Text('Members')),
                  ],
                ),
              ],
            ),
            body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: widget.groupRepository.streamMessages(widget.groupId),
              builder: (BuildContext context,
                  AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot) {
                final List<ChatMessage> messages = (snapshot.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                    .map(ChatMessage.fromDoc)
                    .toList();
                if (_searchMode) {
                  _runSearch(messages);
                }

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
                            color: Colors.amber.shade100,
                            child: ListTile(
                              dense: true,
                              title: Text(
                                'Pinned • ${pinned.senderName}: ${pinned.content.length > 40 ? '${pinned.content.substring(0, 40)}...' : pinned.content}',
                              ),
                              onTap: () => _scrollToMessage(pinned!.id),
                              trailing: isAdmin
                                  ? IconButton(
                                      icon: const Icon(Icons.close),
                                      onPressed: () => widget.groupRepository.pinMessage(
                                        groupId: widget.groupId,
                                        messageId: null,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        if (!canSend)
                          Container(
                            width: double.infinity,
                            color: Colors.orange.shade100,
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
                            children: _messageWidgets(messages, group),
                          ),
                        ),
                        if (_replyTo != null)
                          Container(
                            color: Colors.grey.shade200,
                            padding: const EdgeInsets.all(8),
                            child: Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    'Replying to ${_replyTo!.senderName}: ${_replyTo!.content}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => setState(() => _replyTo = null),
                                  icon: const Icon(Icons.close),
                                ),
                              ],
                            ),
                          ),
                        SafeArea(
                          top: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                            child: Row(
                              children: <Widget>[
                                IconButton(
                                  onPressed: canSend && widget.user.role != UserRole.student
                                      ? () => _attachFile(group)
                                      : null,
                                  icon: const Icon(Icons.attach_file),
                                ),
                                Expanded(
                                  child: TextField(
                                    controller: _textController,
                                    enabled: canSend,
                                    decoration: const InputDecoration(
                                      hintText: 'Type a message',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: canSend ? () => _sendText(group) : null,
                                  icon: const Icon(Icons.send),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: widget.groupRepository.streamFiles(widget.groupId),
                      builder: (BuildContext context,
                          AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> fileSnap) {
                        final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
                            fileSnap.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                        if (docs.isEmpty) {
                          return const Center(child: Text('No files shared yet.'));
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
                            final Map<String, dynamic> file = docs[index].data();
                            final String name = (file['fileName'] as String?) ?? 'File';
                            final String fileType = (file['fileType'] as String?) ?? '';
                            return Card(
                              child: InkWell(
                                onTap: () => _openUrl((file['fileUrl'] as String?) ?? ''),
                                onLongPress: () async {
                                  final String? action = await showModalBottomSheet<String>(
                                    context: context,
                                    builder: (_) => SafeArea(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: <Widget>[
                                          ListTile(
                                            title: const Text('Copy'),
                                            onTap: () => Navigator.of(context).pop('copy'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                  if (action == 'copy') {
                                    await Clipboard.setData(
                                      ClipboardData(
                                        text: (file['fileUrl'] as String?) ?? '',
                                      ),
                                    );
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Copied to clipboard')),
                                    );
                                  }
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: <Widget>[
                                      Icon(
                                        fileType.contains('image')
                                            ? Icons.image
                                            : Icons.picture_as_pdf,
                                        size: 28,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
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
        );
      },
    );
  }
}

