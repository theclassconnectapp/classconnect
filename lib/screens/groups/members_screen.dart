import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/user_role.dart';
import '../../services/group_repository.dart';
import '../widgets/user_avatar.dart';

class MembersScreen extends StatelessWidget {
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

  bool _isSuperAdmin(Map<String, dynamic> group) {
    final String dept = (group['dept'] as String?) ?? '';
    return currentUser.role == UserRole.hod && currentUser.dept == dept;
  }

  bool _isAdmin(Map<String, dynamic> group) {
    final List<dynamic> admins = (group['admins'] as List<dynamic>?) ?? <dynamic>[];
    return admins.contains(currentUser.uid) || _isSuperAdmin(group);
  }

  Future<void> _memberActions(
    BuildContext context, {
    required Map<String, dynamic> group,
    required String memberUid,
    required String memberRole,
    required String memberName,
  }) async {
    if (!_isAdmin(group)) {
      return;
    }
    final List<String> admins =
        ((group['admins'] as List<dynamic>?) ?? <dynamic>[]).cast<String>();
    final List<String> muted =
        ((group['mutedMembers'] as List<dynamic>?) ?? <dynamic>[]).cast<String>();

    final bool memberIsAdmin = admins.contains(memberUid);
    final bool memberIsMuted = muted.contains(memberUid);
    final bool canPromote = memberRole != UserRole.student.id &&
        !memberIsAdmin &&
        memberUid != currentUser.uid;

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
            if (memberIsMuted)
              ListTile(
                title: const Text('Unmute'),
                onTap: () => Navigator.of(context).pop('unmute'),
              ),
            if (!memberIsMuted)
              ListTile(
                title: const Text('Mute'),
                onTap: () => Navigator.of(context).pop('mute'),
              ),
            if (memberUid != currentUser.uid)
              ListTile(
                title: const Text('Remove Member'),
                onTap: () => Navigator.of(context).pop('remove'),
              ),
          ],
        ),
      ),
    );

    if (action == null) {
      return;
    }
    if (action == 'promote') {
      admins.add(memberUid);
      await groupRepository.setGroupAdmins(groupId: groupId, adminUids: admins);
      return;
    }
    if (action == 'mute') {
      muted.add(memberUid);
      await groupRepository.setMutedMembers(groupId: groupId, mutedUids: muted);
      return;
    }
    if (action == 'unmute') {
      muted.remove(memberUid);
      await groupRepository.setMutedMembers(groupId: groupId, mutedUids: muted);
      return;
    }
    if (action == 'remove') {
      await groupRepository.removeMember(groupId: groupId, memberUid: memberUid);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$memberName removed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: groupRepository.streamGroupDoc(groupId),
      builder: (BuildContext context,
          AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> groupSnapshot) {
        final Map<String, dynamic> liveGroup =
            groupSnapshot.data?.data() ?? groupData;
        final List<String> admins =
            ((liveGroup['admins'] as List<dynamic>?) ?? <dynamic>[]).cast<String>();
        final List<String> muted =
            ((liveGroup['mutedMembers'] as List<dynamic>?) ?? <dynamic>[])
                .cast<String>();

        return Scaffold(
          appBar: AppBar(
            title: Text('Members - $groupTitle'),
            actions: <Widget>[
              if (_isAdmin(liveGroup))
                Switch(
                  value: liveGroup['onlyAdminsCanMessage'] as bool? ?? false,
                  onChanged: (bool enabled) {
                    groupRepository.setOnlyAdminsCanMessage(
                      groupId: groupId,
                      enabled: enabled,
                    );
                  },
                ),
            ],
          ),
          body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: groupRepository.streamMembers(groupId),
            builder: (BuildContext context,
                AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text(snapshot.error.toString()));
              }
              final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
                  snapshot.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[];
              if (docs.isEmpty) {
                return const Center(child: Text('No members yet.'));
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                separatorBuilder: (_, int index) => const Divider(height: 1),
                itemBuilder: (_, int index) {
                  final Map<String, dynamic> data = docs[index].data();
                  final String name = (data['name'] as String?) ?? 'Unknown';
                  final String email = (data['email'] as String?) ?? '';
                  final String role = (data['role'] as String?) ?? '';
                  final String? photoUrl = data['photoUrl'] as String?;
                  final String uid = (data['uid'] as String?) ?? '';
                  final bool memberIsAdmin = admins.contains(uid);
                  final bool memberIsMuted = muted.contains(uid);
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
                            child: Text('🔇'),
                          ),
                      ],
                    ),
                    subtitle: Text(
                      [email, role].where((String s) => s.isNotEmpty).join(' • '),
                    ),
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

