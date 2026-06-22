import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../data/repositories/group_repository_impl.dart';
import '../../domain/repositories/group_repository.dart';
import '../../../../shared/widgets/user_avatar.dart';

class MembersScreen extends StatefulWidget {
  const MembersScreen({
    super.key,
    required this.groupId,
    required this.groupTitle,
    required this.groupRepository,
    required this.currentUser,
    required this.groupData,
  });

  final String groupId;
  final String groupTitle;
  final GroupRepository groupRepository;
  final AppUser currentUser;
  final Map<String, dynamic> groupData;

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  Future<void> _toggleMute({
    required BuildContext context,
    required String memberUid,
    required String memberName,
    required bool muted,
  }) async {
    try {
      await widget.groupRepository.setMemberMuted(
        groupId: widget.groupId,
        memberUid: memberUid,
        muted: !muted,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            muted
                ? '$memberName has been unmuted.'
                : '$memberName has been muted.',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            muted
                ? 'Failed to unmute member. Please try again.'
                : 'Failed to mute member. Please try again.',
          ),
        ),
      );
    }
  }

  Future<void> _toggleMessageLock({
    required BuildContext context,
    required bool onlyAdminsCanMessage,
  }) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(
          onlyAdminsCanMessage ? 'Allow all members?' : 'Restrict messages?',
        ),
        content: Text(
          onlyAdminsCanMessage
              ? 'All unmuted members will be able to send messages.'
              : 'Only admins will be able to send messages.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(onlyAdminsCanMessage ? 'Allow all' : 'Restrict'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.groupRepository.setOnlyAdminsCanMessage(
      groupId: widget.groupId,
      enabled: !onlyAdminsCanMessage,
    );
  }

  Future<void> _memberActions(
    BuildContext context, {
    required Map<String, dynamic> group,
    required String memberUid,
    required String memberRole,
    required String memberName,
  }) async {
    if (!canModerateGroup(currentUser: widget.currentUser, group: group)) {
      return;
    }
    final List<String> admins =
        ((group['admins'] as List<dynamic>?) ?? <dynamic>[]).cast<String>();
    final bool memberIsAdmin = admins.contains(memberUid);
    final bool canPromote =
        memberRole != UserRole.student.id &&
        !memberIsAdmin &&
        memberUid != widget.currentUser.uid;
    final String? action = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (canPromote)
              ListTile(
                title: const Text('Make Admin'),
                onTap: () => Navigator.of(context).pop('promote'),
              ),
            if (memberUid != widget.currentUser.uid)
              ListTile(
                title: const Text('Remove Member'),
                onTap: () => Navigator.of(context).pop('remove'),
              ),
          ],
        ),
      ),
    );
    if (action == null) return;
    if (!context.mounted) return;
    if (action == 'promote') {
      try {
        admins.add(memberUid);
        await widget.groupRepository.setGroupAdmins(
          groupId: widget.groupId,
          adminUids: admins,
        );
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$memberName is now an admin.')));
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to promote member. Please try again.'),
          ),
        );
      }
      return;
    }
    if (action == 'remove') {
      try {
        await widget.groupRepository.removeMember(
          groupId: widget.groupId,
          memberUid: memberUid,
        );
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$memberName removed.')));
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to remove member. Please try again.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: widget.groupRepository.streamGroupDoc(widget.groupId),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> groupSnapshot,
          ) {
            final Map<String, dynamic> liveGroup =
                groupSnapshot.data?.data() ?? widget.groupData;
            final List<String> admins =
                ((liveGroup['admins'] as List<dynamic>?) ?? <dynamic>[])
                    .cast<String>();
            final List<String> muted =
                ((liveGroup['mutedUids'] as List<dynamic>?) ?? <dynamic>[])
                    .cast<String>();
            final bool canModerate = canModerateGroup(
              currentUser: widget.currentUser,
              group: liveGroup,
            );
            final bool onlyAdminsCanMessage =
                liveGroup['onlyAdminsCanMessage'] as bool? ?? false;
            return Scaffold(
              appBar: AppBar(
                title: Text('Members - ${widget.groupTitle}'),
                actions: <Widget>[
                  if (canModerate)
                    IconButton(
                      icon: Icon(
                        onlyAdminsCanMessage
                            ? Icons.lock_outline
                            : Icons.lock_open_outlined,
                      ),
                      tooltip: onlyAdminsCanMessage
                          ? 'Only admins can message - tap to allow all'
                          : 'All members can message - tap to restrict',
                      onPressed: () => _toggleMessageLock(
                        context: context,
                        onlyAdminsCanMessage: onlyAdminsCanMessage,
                      ),
                    ),
                ],
              ),
              body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: widget.groupRepository.streamMembers(widget.groupId),
                builder:
                    (
                      BuildContext context,
                      AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>>
                      snapshot,
                    ) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text(snapshot.error.toString()));
                      }
                      final List<QueryDocumentSnapshot<Map<String, dynamic>>>
                      docs =
                          snapshot.data?.docs ??
                          <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                      if (docs.isEmpty) {
                        return const Center(child: Text('No members yet.'));
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: docs.length,
                        separatorBuilder: (_, int index) =>
                            const Divider(height: 1),
                        itemBuilder: (_, int index) {
                          final Map<String, dynamic> data = docs[index].data();
                          final String name =
                              (data['name'] as String?) ?? 'Unknown';
                          final String email = (data['email'] as String?) ?? '';
                          final String role = (data['role'] as String?) ?? '';
                          final String? photoUrl = data['photoUrl'] as String?;
                          final String uid =
                              (data['uid'] as String?)?.isNotEmpty == true
                              ? data['uid'] as String
                              : docs[index].id;
                          final bool memberIsAdmin = admins.contains(uid);
                          final bool memberIsMuted = muted.contains(uid);
                          final bool memberIsStudent =
                              role == UserRole.student.id;
                          return ListTile(
                            leading: UserAvatar(name: name, photoUrl: photoUrl),
                            title: Row(
                              children: <Widget>[
                                Expanded(child: Text(name)),
                                if (memberIsAdmin)
                                  const Padding(
                                    padding: EdgeInsets.only(left: 6),
                                    child: Chip(label: Text('Admin')),
                                  ),
                                if (memberIsMuted)
                                  const Padding(
                                    padding: EdgeInsets.only(left: 6),
                                    child: Chip(label: Text('Muted')),
                                  ),
                              ],
                            ),
                            subtitle: Text(
                              <String>[
                                email,
                                role,
                              ].where((String s) => s.isNotEmpty).join(' • '),
                            ),
                            trailing: canModerate && memberIsStudent
                                ? IconButton(
                                    tooltip: memberIsMuted ? 'Unmute' : 'Mute',
                                    icon: Icon(
                                      memberIsMuted
                                          ? Icons.volume_up_outlined
                                          : Icons.volume_off_outlined,
                                    ),
                                    onPressed: () => _toggleMute(
                                      context: context,
                                      memberUid: uid,
                                      memberName: name,
                                      muted: memberIsMuted,
                                    ),
                                  )
                                : null,
                            onLongPress: () => _memberActions(
                              context,
                              group: liveGroup,
                              memberUid: uid,
                              memberRole: role,
                              memberName: name,
                            ),
                          );
                        },
                      );
                    },
              ),
            );
          },
    );
  }
}
