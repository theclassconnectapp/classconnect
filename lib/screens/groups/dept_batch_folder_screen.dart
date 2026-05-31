import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/app_user.dart';
import '../../models/group_models.dart';
import '../../models/user_role.dart';
import '../../services/group_repository.dart';
import 'create_group_screen.dart';
import 'group_chat_screen.dart';

class DeptBatchFolderScreen extends StatelessWidget {
  const DeptBatchFolderScreen({
    super.key,
    required this.user,
    required this.dept,
    required this.batch,
    required this.groupRepository,
  });

  final AppUser user;
  final String dept;
  final String batch;
  final GroupRepository groupRepository;

  bool get _canCreateSubject =>
      user.role == UserRole.subjectTeacher || user.role == UserRole.hod;

  Future<void> _createSubject(BuildContext context) async {
    final Map<String, String>? result = await Navigator.of(context).push(
      MaterialPageRoute<Map<String, String>>(
        builder: (_) => const CreateGroupScreen(allowGeneral: false),
      ),
    );
    if (result == null) {
      return;
    }
    await groupRepository.createSubjectGroup(
      name: result['name'] ?? 'Subject Group',
      dept: dept,
      batch: batch,
      createdByUid: user.uid,
      createdByName: user.name,
      description: result['description'] ?? '',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$dept $batch'),
      ),
      floatingActionButton: _canCreateSubject
          ? FloatingActionButton.extended(
              onPressed: () => _createSubject(context),
              icon: const Icon(Icons.add),
              label: const Text('Create Subject'),
            )
          : null,
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: groupRepository.streamGroupsInFolder(dept: dept, batch: batch),
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
            return const Center(child: Text('No groups yet.'));
          }
          docs.sort((a, b) {
            final String typeA = (a.data()['type'] as String?) ?? '';
            final String typeB = (b.data()['type'] as String?) ?? '';
            if (typeA == typeB) return 0;
            if (typeA == GroupType.general.id) return -1;
            if (typeB == GroupType.general.id) return 1;
            return 0;
          });
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, int index) => const SizedBox(height: 8),
            itemBuilder: (_, int index) {
              final QueryDocumentSnapshot<Map<String, dynamic>> doc = docs[index];
              final Map<String, dynamic> data = doc.data();
              final GroupModel group = GroupModel.fromDoc(doc);
              final DateTime? previewTime =
                  (data['lastMessageTime'] as Timestamp?)?.toDate();
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      group.name.isEmpty ? '?' : group.name[0].toUpperCase(),
                    ),
                  ),
                  title: Text(group.name),
                  subtitle: Text(group.type == GroupType.general
                      ? 'General Group'
                      : 'Subject Group'),
                  trailing: Text(
                    previewTime == null ? '' : DateFormat.Hm().format(previewTime),
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => GroupChatScreen(
                          groupId: doc.id,
                          groupData: data,
                          user: user,
                          groupRepository: groupRepository,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

