import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../auth/presentation/screens/profile_screen.dart';
import '../../domain/repositories/group_repository.dart';
import 'semester_screen.dart';

enum _DashboardMenuAction { profile, signOut }

class FolderListScreen extends StatelessWidget {
  const FolderListScreen({
    super.key,
    required this.title,
    required this.user,
    required this.groupRepository,
  });

  final String title;
  final AppUser user;
  final GroupRepository groupRepository;

  Future _handleMenu(BuildContext context, _DashboardMenuAction action) async {
    switch (action) {
      case _DashboardMenuAction.profile:
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProfileScreen(
              user: user,
              onSignOut: () => context.read<AuthCubit>().signOut(),
            ),
          ),
        );
        return;
      case _DashboardMenuAction.signOut:
        final bool? confirm = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Sign out'),
            content: const Text('You are about to sign out. Are you sure?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Yes'),
              ),
            ],
          ),
        );
        if (confirm == true && context.mounted) {
          context.read<AuthCubit>().signOut();
        }
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
      if (dept.isEmpty || batch.isEmpty) continue;
      final String key = '$dept|$batch';
      if (seen.add(key)) {
        folders.add(<String, String>{'dept': dept, 'batch': batch});
      }
    }
    folders.sort((a, b) {
      final int deptCompare = a['dept']!.compareTo(b['dept']!);
      if (deptCompare != 0) return deptCompare;
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
        builder:
            (
              BuildContext context,
              AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
            ) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text(snapshot.error.toString()));
              }
              final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
                  snapshot.data?.docs ?? [];
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
                            builder: (_) => SemesterScreen(
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
