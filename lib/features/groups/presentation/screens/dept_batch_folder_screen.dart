import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/injection_container.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../../college/domain/repositories/college_repository.dart'
    as college_domain;
import '../../data/models/group_models.dart';
import '../../data/repositories/group_repository_impl.dart';
import '../../domain/repositories/group_repository.dart';
import '../../data/repositories/semester_repository_impl.dart';
import '../../../ai/presentation/screens/ai_assistant_screen.dart';
import 'create_group_screen.dart';
import 'group_chat_screen.dart';

class DeptBatchFolderScreen extends StatefulWidget {
  const DeptBatchFolderScreen({
    super.key,
    required this.user,
    required this.dept,
    required this.batch,
    required this.groupRepository,
    this.semester,
    this.readOnly = false,
  });

  final AppUser user;
  final String dept;
  final String batch;
  final GroupRepository groupRepository;
  final String? semester;
  final bool readOnly;

  @override
  State<DeptBatchFolderScreen> createState() => _DeptBatchFolderScreenState();
}

class _DeptBatchFolderScreenState extends State<DeptBatchFolderScreen> {
  bool get _canCreateSubject =>
      widget.user.role == UserRole.subjectTeacher ||
      widget.user.role == UserRole.hod ||
      widget.user.role == UserRole.advisor;

  Future _createSubject(BuildContext context) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateGroupScreen(
          allowGeneral: false,
          collegeRepository: sl<college_domain.CollegeRepository>(),
        ),
      ),
    );
    if (result == null) return;
    if (!context.mounted) return;
    final String name = (result['name'] as String?) ?? 'Subject Group';
    final String description = (result['description'] as String?) ?? '';
    try {
      final String currentSemester =
          SemesterService.currentSemesterLabel(widget.batch) ?? '';
      await widget.groupRepository.createSubjectGroup(
        name: name,
        dept: widget.dept,
        batch: widget.batch,
        semester: currentSemester,
        createdByUid: widget.user.uid,
        createdByName: widget.user.name,
        description: description,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subject group created successfully.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to create group. Please try again.'),
        ),
      );
    }
  }

  void _openAi({String? groupId}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AiAssistantScreen(
          scope: groupId != null ? AiScope.group : AiScope.semester,
          semesterId: '${widget.dept}_${widget.batch}',
          groupId: groupId,
        ),
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
          if (!context.mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Group deleted.')));
        } catch (e) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to delete group: $e')));
        }
      }
    } finally {
      confirmController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final String resolvedSem =
        widget.semester ??
        SemesterService.currentSemesterLabel(widget.batch) ??
        '';
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.readOnly
              ? '${widget.dept} ${widget.batch} — $resolvedSem'
              : '${widget.dept} ${widget.batch}',
        ),
      ),
      floatingActionButton: (_canCreateSubject && !widget.readOnly)
          ? FloatingActionButton.extended(
              onPressed: () => _createSubject(context),
              icon: const Icon(Icons.add),
              label: const Text('Create Subject'),
            )
          : null,
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: widget.groupRepository.streamGroupsInFolder(
          dept: widget.dept,
          batch: widget.batch,
          semester: resolvedSem,
        ),
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
              final List<QueryDocumentSnapshot<Map<String, dynamic>>>
              filteredDocs = docs.where((doc) {
                final Map<String, dynamic> data = doc.data();
                final Object? isGeneral = data['isGeneral'];
                final String docSemester = (data['semester'] as String?) ?? '';
                return isGeneral == true || docSemester == resolvedSem;
              }).toList();

              filteredDocs.sort((a, b) {
                final String typeA = (a.data()['type'] as String?) ?? '';
                final String typeB = (b.data()['type'] as String?) ?? '';
                if (typeA == typeB) return 0;
                if (typeA == GroupType.general.id) return -1;
                if (typeB == GroupType.general.id) return 1;
                return 0;
              });

              final int totalItems = filteredDocs.isEmpty
                  ? 1
                  : filteredDocs.length + 1;

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: totalItems,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, int index) {
                  if (index == 0) {
                    return _AiCard(onTap: () => _openAi());
                  }
                  if (filteredDocs.isEmpty) return const SizedBox.shrink();
                  final QueryDocumentSnapshot<Map<String, dynamic>> doc =
                      filteredDocs[index - 1];
                  final Map<String, dynamic> data = doc.data();
                  final GroupModel group = GroupModel.fromDoc(doc);
                  final DateTime? previewTime =
                      (data['lastMessageTime'] as Timestamp?)?.toDate();
                  final bool isSubject = group.type != GroupType.general;
                  final bool showDelete = canDeleteGroup(
                    groupData: data,
                    currentUser: widget.user,
                  );

                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          group.name.isEmpty
                              ? '?'
                              : group.name[0].toUpperCase(),
                        ),
                      ),
                      title: Text(group.name),
                      subtitle: Text(
                        group.type == GroupType.general
                            ? 'General Group'
                            : 'Subject Group',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (previewTime != null)
                            Text(DateFormat.Hm().format(previewTime)),
                          if (isSubject) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.auto_awesome, size: 20),
                              tooltip: 'Ask AI',
                              onPressed: () => _openAi(groupId: doc.id),
                            ),
                          ],
                        ],
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => GroupChatScreen(
                              groupId: doc.id,
                              groupData: data,
                              user: widget.user,
                              groupRepository: widget.groupRepository,
                              readOnly: widget.readOnly,
                            ),
                          ),
                        );
                      },
                      onLongPress: showDelete
                          ? () => _confirmDeleteGroup(
                              context,
                              doc.id,
                              group.name.isEmpty ? 'this group' : group.name,
                            )
                          : null,
                    ),
                  );
                },
              );
            },
      ),
    );
  }
}

class _AiCard extends StatelessWidget {
  const _AiCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: colorScheme.primaryContainer,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: colorScheme.primary,
          child: Icon(Icons.auto_awesome, color: colorScheme.onPrimary),
        ),
        title: Text(
          'Ask AI',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: colorScheme.onPrimaryContainer,
          ),
        ),
        subtitle: Text(
          'Summarize topics, get help with subjects',
          style: TextStyle(
            color: colorScheme.onPrimaryContainer.withValues(alpha: 0.75),
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: colorScheme.onPrimaryContainer,
        ),
        onTap: onTap,
      ),
    );
  }
}
