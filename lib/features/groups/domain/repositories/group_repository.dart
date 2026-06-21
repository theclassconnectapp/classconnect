import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';

import '../../../auth/domain/entities/app_user.dart';
import '../../data/models/group_models.dart';

abstract class GroupRepository {
  String generalGroupId({
    required String dept,
    required String batch,
    required String semester,
  });

  Future<void> ensureGeneralGroupExists({
    required String dept,
    required String batch,
    required String semester,
    required String advisorUid,
    required String advisorName,
  });

  Future<void> addMember({required String groupId, required AppUser user});

  Future<void> removeMember({
    required String groupId,
    required String memberUid,
  });

  Future<void> syncMembership(AppUser user);

  Future<void> createSubjectGroup({
    required String name,
    required String dept,
    required String batch,
    required String semester,
    required String createdByUid,
    required String createdByName,
    required String description,
  });

  Stream<QuerySnapshot<Map<String, dynamic>>> streamGroupsForUser(AppUser user);

  Stream<QuerySnapshot<Map<String, dynamic>>> streamGroupsInFolder({
    required String dept,
    required String batch,
    String? semester,
  });

  Stream<QuerySnapshot<Map<String, dynamic>>> streamMembers(String groupId);
  Stream<QuerySnapshot<Map<String, dynamic>>> streamMessages(String groupId);
  Stream<QuerySnapshot<Map<String, dynamic>>> streamFiles(String groupId);
  Stream<DocumentSnapshot<Map<String, dynamic>>> streamGroupDoc(String groupId);

  Future<void> sendTextMessage({
    required String groupId,
    required AppUser sender,
    required String text,
    Map<String, dynamic>? replyTo,
    bool isForwarded,
  });

  Future<void> sendFileMessage({
    required String groupId,
    required AppUser sender,
    required MessageType type,
    required String fileName,
    required String mimeType,
    required int fileSize,
    String? localPath,
    Uint8List? bytes,
    Map<String, dynamic>? replyTo,
    bool isForwarded,
  });

  Future<void> markGroupSeen({required String groupId, required String uid});

  Future<int> unreadCountFor({required String groupId, required String uid});

  Future<void> reactToMessage({
    required String groupId,
    required String messageId,
    required String uid,
    required String reaction,
  });

  Future<void> forwardMessage({
    required String sourceGroupId,
    required String messageId,
    required String targetGroupId,
    required AppUser sender,
  });

  Future<void> deleteMessage({
    required String groupId,
    required String messageId,
    required String deletedByUid,
  });

  Future<void> setGroupAdmins({
    required String groupId,
    required List<String> adminUids,
  });

  Future<void> setMutedMembers({
    required String groupId,
    required List<String> mutedUids,
  });

  Future<void> setOnlyAdminsCanMessage({
    required String groupId,
    required bool enabled,
  });

  Future<void> updateGroupInfo({
    required String groupId,
    required String name,
    required String description,
  });

  Future<void> deleteGroup({required String groupId});

  Future<String> uploadGroupPhoto({
    required String groupId,
    required PlatformFile file,
  });

  Future<void> setGroupPhotoUrl({
    required String groupId,
    required String? photoUrl,
  });

  Future<void> pinMessage({
    required String groupId,
    required String? messageId,
  });

  Future<void> deleteFile({required String groupId, required String fileId});
}
