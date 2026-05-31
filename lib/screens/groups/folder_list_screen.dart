import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../services/group_repository.dart';
import '../profile/profile_screen.dart';
import 'dept_batch_folder_screen.dart';

enum _DashboardMenuAction { profile, signOut }

class FolderListScreen extends StatelessWidget {
  const FolderListScreen({
    super.key,
    required this.title,
    required this.user,
    required this.groupRepository,
    required this.onSignOut,
  });

  final String title;
  final AppUser user;
  final GroupRepository groupRepository;
  final VoidCallback onSignOut;

  Future<void> _handleMenu(
    BuildContext context,
    _DashboardMenuAction action,
  ) async {
    switch (action) {
      case _DashboardMenuAction.profile:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => ProfileScreen(user: user)),
        );
        return;
      case _DashboardMenuAction.signOut:
        onSignOut();
        return;
    }
  }

  List<Map<String, String>> _foldersFromDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final Set<String> seen = <String>{};
    final List<Map<String, String>> folders = <Map<String, String>>[];
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in docs) {
      final Map<String, dynamic> data = doc.data();
      final String dept = (data['dept'] as String?) ?? '';
      final String batch = (data['batch'] as String?) ?? '';
      if (dept.isEmpty || batch.isEmpty) {
        continue;
      }
      final String key = '$dept|$batch';
      if (seen.add(key)) {
        folders.add(<String, String>{'dept': dept, 'batch': batch});
      }
    }
    folders.sort((a, b) {
      final int deptCompare = a['dept']!.compareTo(b['dept']!);
      if (deptCompare != 0) {
        return deptCompare;
      }
      return a['batch']!.compareTo(b['batch']!);
    });
    return folders;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: <Widget>[
          PopupMenuButton<_DashboardMenuAction>(
            onSelected: (_DashboardMenuAction a) => _handleMenu(context, a),
            itemBuilder: (_) => const <PopupMenuEntry<_DashboardMenuAction>>[
              PopupMenuItem<_DashboardMenuAction>(
                value: _DashboardMenuAction.profile,
                child: Text('Profile'),
              ),
              PopupMenuDivider(),
              PopupMenuItem<_DashboardMenuAction>(
                value: _DashboardMenuAction.signOut,
                child: Text('Sign out'),
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: groupRepository.streamGroupsForUser(user),
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
          final List<Map<String, String>> folders = _foldersFromDocs(docs);
          if (folders.isEmpty) {
            return const Center(child: Text('No folders found.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: folders.length,
            separatorBuilder: (_, int index) => const SizedBox(height: 8),
            itemBuilder: (_, int index) {
              final Map<String, String> folder = folders[index];
              return Card(
                child: ListTile(
                  title: Text('${folder['dept']} ${folder['batch']}'),
                  subtitle: const Text('Open folder'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => DeptBatchFolderScreen(
                          user: user,
                          dept: folder['dept']!,
                          batch: folder['batch']!,
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

