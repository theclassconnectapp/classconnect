import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../../college/domain/entities/user_scope.dart';
import '../../domain/repositories/group_repository.dart';
import '../models/group_models.dart';
import 'semester_repository_impl.dart';

bool canDeleteGroup({
  required Map<String, dynamic> groupData,
  required AppUser currentUser,
}) {
  final bool isGeneral = groupData['isGeneral'] == true;
  if (isGeneral) return false;
  final String? createdByUid = groupData['createdByUid'] as String?;
  if (createdByUid != null && createdByUid == currentUser.uid) return true;
  if (currentUser.role == UserRole.hod ||
      currentUser.role == UserRole.advisor) {
    return true;
  }
  return false;
}

class GroupRepositoryImpl implements GroupRepository {
  GroupRepositoryImpl({
    required this.collegeId,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance;

  final String collegeId;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _groups =>
      _firestore.collection('colleges').doc(collegeId).collection('groups');

  DocumentReference<Map<String, dynamic>> _groupRef(String groupId) =>
      _groups.doc(groupId);

  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> streamGroupDoc(
    String groupId,
  ) => _groupRef(groupId).snapshots();

  @override
  String generalGroupId({
    required String dept,
    required String batch,
    required String semester,
  }) => 'general_${dept}_${batch}_$semester'.toLowerCase().replaceAll(' ', '_');

  @override
  Future<void> ensureGeneralGroupExists({
    required String dept,
    required String batch,
    required String semester,
    required String advisorUid,
    required String advisorName,
  }) async {
    final DocumentReference<Map<String, dynamic>> ref = _groupRef(
      generalGroupId(dept: dept, batch: batch, semester: semester),
    );
    await _firestore.runTransaction((Transaction txn) async {
      final DocumentSnapshot<Map<String, dynamic>> snap = await txn.get(ref);
      final Map<String, dynamic> groupData = <String, dynamic>{
        'name': '$dept $batch - General',
        'type': GroupType.general.id,
        'dept': dept,
        'batch': batch,
        'semester': semester,
        'description': 'General class group',
      };
      if (!snap.exists) {
        groupData.addAll(<String, dynamic>{
          'createdByUid': advisorUid,
          'createdByName': advisorName,
          'createdAt': FieldValue.serverTimestamp(),
          'admins': <String>[advisorUid],
          'mutedMembers': <String>[],
          'onlyAdminsCanMessage': false,
          'photoUrl': null,
          'pinnedMessageId': null,
        });
      }
      txn.set(ref, groupData, SetOptions(merge: true));
    });
  }

  @override
  Future<void> addMember({
    required String groupId,
    required AppUser user,
  }) async {
    final DocumentReference<Map<String, dynamic>> group = _groupRef(groupId);
    final DocumentReference<Map<String, dynamic>> member = group
        .collection('members')
        .doc(user.uid);
    final DocumentReference<Map<String, dynamic>> state = group
        .collection('states')
        .doc(user.uid);
    await _firestore.runTransaction((Transaction txn) async {
      txn.set(member, <String, dynamic>{
        'uid': user.uid,
        'name': user.name,
        'email': user.email,
        'role': user.role.id,
        'photoUrl': user.photoUrl,
        'joinedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      txn.set(group, <String, dynamic>{
        'memberIds': FieldValue.arrayUnion(<String>[user.uid]),
      }, SetOptions(merge: true));
      txn.set(state, <String, dynamic>{
        'uid': user.uid,
        'lastSeenAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
    final DocumentSnapshot<Map<String, dynamic>> groupSnap = await group.get();
    final String type = (groupSnap.data()?['type'] as String?) ?? '';
    if (type == GroupType.subject.id) {
      await group.collection('messages').add(<String, dynamic>{
        'uid': 'system',
        'senderName': 'system',
        'senderPhoto': null,
        'type': 'system',
        'content': '${user.name} joined the group',
        'fileUrl': null,
        'fileName': null,
        'fileType': null,
        'fileSize': null,
        'isDeleted': false,
        'timestamp': FieldValue.serverTimestamp(),
        'reactions': <String, dynamic>{},
        'replyTo': null,
        'isForwarded': false,
      });
      await group.set(<String, dynamic>{
        'lastMessageText': '${user.name} joined the group',
        'lastMessageTime': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  @override
  Future<void> removeMember({
    required String groupId,
    required String memberUid,
  }) async {
    final DocumentReference<Map<String, dynamic>> ref = _groupRef(groupId);
    await ref.collection('members').doc(memberUid).delete();
    await ref.collection('states').doc(memberUid).delete();
    await ref.set(<String, dynamic>{
      'memberIds': FieldValue.arrayRemove(<String>[memberUid]),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> syncMembership(AppUser user) async {
    if (user.dept == null || user.batch == null) return;

    String? groupId;

    if (user.batchId != null && user.batchId!.isNotEmpty) {
      final QuerySnapshot<Map<String, dynamic>> matches = await _groups
          .where('batchId', isEqualTo: user.batchId)
          .where('isGeneral', isEqualTo: true)
          .limit(1)
          .get();
      if (matches.docs.isNotEmpty) {
        groupId = matches.docs.first.id;
      }
    }

    if (groupId == null) {
      final String currentSem =
          SemesterService.currentSemesterLabel(user.batch!) ?? '';
      final String legacyId = generalGroupId(
        dept: user.dept!,
        batch: user.batch!,
        semester: currentSem,
      );
      if (user.role == UserRole.advisor) {
        await ensureGeneralGroupExists(
          dept: user.dept!,
          batch: user.batch!,
          semester: currentSem,
          advisorUid: user.uid,
          advisorName: user.name,
        );
        groupId = legacyId;
      } else {
        final DocumentSnapshot<Map<String, dynamic>> groupSnap =
            await _groupRef(legacyId).get();
        if (groupSnap.exists) {
          groupId = legacyId;
        }
      }
    }

    if (groupId == null) return;
    await addMember(groupId: groupId, user: user);
  }

  @override
  Future<void> createSubjectGroup({
    required String name,
    required String dept,
    required String batch,
    required String semester,
    required String createdByUid,
    required String createdByName,
    required String description,
  }) async {
    final DocumentReference<Map<String, dynamic>> group = _groups.doc();
    final DocumentReference<Map<String, dynamic>> member = group
        .collection('members')
        .doc(createdByUid);
    final DocumentReference<Map<String, dynamic>> state = group
        .collection('states')
        .doc(createdByUid);
    final WriteBatch batchWrite = _firestore.batch();
    batchWrite.set(group, <String, dynamic>{
      'name': name.trim(),
      'type': GroupType.subject.id,
      'dept': dept,
      'batch': batch,
      'semester': semester,
      'createdByUid': createdByUid,
      'createdByName': createdByName,
      'createdAt': FieldValue.serverTimestamp(),
      'description': description.trim(),
      'memberIds': <String>[createdByUid],
      'admins': <String>[createdByUid],
      'mutedMembers': <String>[],
      'onlyAdminsCanMessage': false,
      'photoUrl': null,
      'pinnedMessageId': null,
    });
    batchWrite.set(member, <String, dynamic>{
      'uid': createdByUid,
      'name': createdByName,
      'role': UserRole.subjectTeacher.id,
      'joinedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batchWrite.set(state, <String, dynamic>{
      'uid': createdByUid,
      'lastSeenAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await batchWrite.commit();
  }

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> streamGroupsForUser(
    AppUser user,
  ) {
    switch (user.role) {
      case UserRole.hod:
        return _streamGroupsForStaffScopes(user.staffScopes);
      case UserRole.advisor:
      case UserRole.student:
        if (user.dept == null || user.batch == null) {
          return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
        }
        return _groups
            .where('dept', isEqualTo: user.dept)
            .where('batch', isEqualTo: user.batch)
            .snapshots();
      case UserRole.subjectTeacher:
        return _streamGroupsForStaffScopes(user.staffScopes);
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _streamGroupsForStaffScopes(
    List<UserScope>? scopes,
  ) {
    if (scopes == null || scopes.isEmpty) {
      return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
    }

    final List<Filter> filters = scopes.take(30).map(_filterForScope).toList();
    if (filters.length == 1) {
      return _groups.where(filters.first).snapshots();
    }
    return _groups.where(_orFilters(filters)).snapshots();
  }

  Filter _filterForScope(UserScope scope) {
    final String? batchId = scope.batchId;
    if (batchId == null || batchId.isEmpty) {
      return Filter('departmentId', isEqualTo: scope.departmentId);
    }
    return Filter.and(
      Filter('departmentId', isEqualTo: scope.departmentId),
      Filter('batchId', isEqualTo: batchId),
    );
  }

  Filter _orFilters(List<Filter> filters) {
    if (filters.length == 1) {
      return filters.first;
    }
    return Filter.or(filters.first, _orFilters(filters.sublist(1)));
  }

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> streamGroupsInFolder({
    required String dept,
    required String batch,
    String? semester,
  }) {
    final Query<Map<String, dynamic>> q = _groups
        .where('dept', isEqualTo: dept)
        .where('batch', isEqualTo: batch);
    return q.snapshots();
  }

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> streamMembers(String groupId) {
    return _groupRef(
      groupId,
    ).collection('members').orderBy('joinedAt', descending: true).snapshots();
  }

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> streamMessages(String groupId) {
    return _groupRef(
      groupId,
    ).collection('messages').orderBy('timestamp').snapshots();
  }

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> streamFiles(String groupId) {
    return _groupRef(
      groupId,
    ).collection('files').orderBy('uploadedAt', descending: true).snapshots();
  }

  @override
  Future<void> sendTextMessage({
    required String groupId,
    required AppUser sender,
    required String text,
    Map<String, dynamic>? replyTo,
    bool isForwarded = false,
  }) async {
    try {
      final String clean = text.trim();
      final bool isLink =
          clean.startsWith('http://') || clean.startsWith('https://');
      await _groupRef(groupId).collection('messages').add(<String, dynamic>{
        'uid': sender.uid,
        'senderName': sender.name,
        'senderPhoto': sender.photoUrl,
        'type': isLink ? MessageType.link.id : MessageType.text.id,
        'content': clean,
        'fileUrl': null,
        'fileName': null,
        'fileType': null,
        'fileSize': null,
        'isDeleted': false,
        'timestamp': FieldValue.serverTimestamp(),
        'reactions': <String, dynamic>{},
        'replyTo': replyTo,
        'isForwarded': isForwarded,
        'status': 'sent',
      });
      await _groupRef(groupId).set(<String, dynamic>{
        'lastMessageText': clean,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderUid': sender.uid,
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to send message: $e');
    }
  }

  Future<String> _uploadToStorage({
    required String groupId,
    required String fileName,
    required String mimeType,
    String? filePath,
    Uint8List? bytes,
  }) async {
    try {
      final Uri uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/degztafwr/auto/upload',
      );
      final http.MultipartRequest request = http.MultipartRequest('POST', uri);
      request.fields['upload_preset'] = 'classconnect_files';
      request.fields['folder'] = 'classconnect/groups/$groupId';
      if (bytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: fileName,
            contentType: MediaType.parse(mimeType),
          ),
        );
      } else if (filePath != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'file',
            filePath,
            contentType: MediaType.parse(mimeType),
          ),
        );
      } else {
        throw Exception('Missing file bytes/path');
      }
      final http.StreamedResponse response = await request.send();
      final String body = await response.stream.bytesToString();
      if (response.statusCode != 200) {
        throw Exception('Cloudinary upload failed: $body');
      }
      final Map<String, dynamic> json =
          jsonDecode(body) as Map<String, dynamic>;
      return json['secure_url'] as String;
    } catch (e) {
      throw Exception('Upload failed: $e');
    }
  }

  @override
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
    bool isForwarded = false,
  }) async {
    try {
      final String url = await _uploadToStorage(
        groupId: groupId,
        fileName: fileName,
        mimeType: mimeType,
        filePath: localPath,
        bytes: bytes,
      );
      final WriteBatch write = _firestore.batch();
      final DocumentReference<Map<String, dynamic>> msgRef = _groupRef(
        groupId,
      ).collection('messages').doc();
      final DocumentReference<Map<String, dynamic>> fileRef = _groupRef(
        groupId,
      ).collection('files').doc();
      write.set(msgRef, <String, dynamic>{
        'uid': sender.uid,
        'senderName': sender.name,
        'senderPhoto': sender.photoUrl,
        'type': type.id,
        'content': fileName,
        'fileUrl': url,
        'fileName': fileName,
        'fileType': mimeType,
        'fileSize': fileSize,
        'isDeleted': false,
        'timestamp': FieldValue.serverTimestamp(),
        'reactions': <String, dynamic>{},
        'replyTo': replyTo,
        'isForwarded': isForwarded,
        'status': 'sent',
      });
      write.set(_groupRef(groupId), <String, dynamic>{
        'lastMessageText': fileName,
        'lastMessageTime': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      write.set(fileRef, <String, dynamic>{
        'uploadedByUid': sender.uid,
        'fileName': fileName,
        'fileUrl': url,
        'fileType': mimeType,
        'fileSize': fileSize,
        'uploadedAt': FieldValue.serverTimestamp(),
      });
      await write.commit();
    } catch (e) {
      throw Exception('Failed to send file message: $e');
    }
  }

  @override
  Future<void> markGroupSeen({
    required String groupId,
    required String uid,
  }) async {
    await _groupRef(groupId).collection('states').doc(uid).set(
      <String, dynamic>{'uid': uid, 'lastSeenAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  @override
  Future<int> unreadCountFor({
    required String groupId,
    required String uid,
  }) async {
    final DocumentSnapshot<Map<String, dynamic>> state = await _groupRef(
      groupId,
    ).collection('states').doc(uid).get();
    final Timestamp? seen = state.data()?['lastSeenAt'] as Timestamp?;
    Query<Map<String, dynamic>> q = _groupRef(
      groupId,
    ).collection('messages').where('uid', isNotEqualTo: uid);
    if (seen != null) {
      q = q.where('timestamp', isGreaterThan: seen);
    }
    final AggregateQuerySnapshot count = await q.count().get();
    return count.count ?? 0;
  }

  @override
  Future<void> reactToMessage({
    required String groupId,
    required String messageId,
    required String uid,
    required String reaction,
  }) async {
    try {
      await _groupRef(groupId).collection('messages').doc(messageId).set(
        <String, dynamic>{'reactions.$uid': reaction},
        SetOptions(merge: true),
      );
    } catch (e) {
      throw Exception('Failed to react: $e');
    }
  }

  @override
  Future<void> forwardMessage({
    required String sourceGroupId,
    required String messageId,
    required String targetGroupId,
    required AppUser sender,
  }) async {
    final DocumentSnapshot<Map<String, dynamic>> source = await _groupRef(
      sourceGroupId,
    ).collection('messages').doc(messageId).get();
    if (!source.exists) return;
    final Map<String, dynamic> data = source.data() ?? <String, dynamic>{};
    final String typeId = data['type'] as String? ?? MessageType.text.id;
    final MessageType type = MessageType.fromId(typeId);
    if (type == MessageType.text || type == MessageType.link) {
      await sendTextMessage(
        groupId: targetGroupId,
        sender: sender,
        text: data['content'] as String? ?? '',
        isForwarded: true,
      );
      return;
    }
    await _groupRef(targetGroupId).collection('messages').add(<String, dynamic>{
      'uid': sender.uid,
      'senderName': sender.name,
      'senderPhoto': sender.photoUrl,
      'type': type.id,
      'content': data['content'] as String? ?? '',
      'fileUrl': data['fileUrl'],
      'fileName': data['fileName'],
      'fileType': data['fileType'],
      'fileSize': data['fileSize'],
      'isDeleted': false,
      'timestamp': FieldValue.serverTimestamp(),
      'reactions': <String, dynamic>{},
      'replyTo': null,
      'isForwarded': true,
    });
    await _groupRef(targetGroupId).set(<String, dynamic>{
      'lastMessageText': data['content'] ?? 'Forwarded file',
      'lastMessageTime': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> deleteMessage({
    required String groupId,
    required String messageId,
    required String deletedByUid,
  }) async {
    try {
      await _groupRef(
        groupId,
      ).collection('messages').doc(messageId).set(<String, dynamic>{
        'isDeleted': true,
        'deletedByUid': deletedByUid,
        'deletedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to delete message: $e');
    }
  }

  @override
  Future<void> setGroupAdmins({
    required String groupId,
    required List<String> adminUids,
  }) async {
    await _groupRef(groupId).set(<String, dynamic>{
      'admins': adminUids.toSet().toList(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> setMutedMembers({
    required String groupId,
    required List<String> mutedUids,
  }) async {
    await _groupRef(groupId).set(<String, dynamic>{
      'mutedMembers': mutedUids.toSet().toList(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> setOnlyAdminsCanMessage({
    required String groupId,
    required bool enabled,
  }) async {
    await _groupRef(groupId).set(<String, dynamic>{
      'onlyAdminsCanMessage': enabled,
    }, SetOptions(merge: true));
  }

  @override
  Future<void> updateGroupInfo({
    required String groupId,
    required String name,
    required String description,
  }) async {
    await _groupRef(groupId).set(<String, dynamic>{
      'name': name.trim(),
      'description': description.trim(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> deleteGroup({required String groupId}) async {
    // Firestore does not cascade-delete subcollections; members/messages/files/states
    // can be cleaned up by a background job later if needed.
    await _groupRef(groupId).delete();
  }

  @override
  Future<String> uploadGroupPhoto({
    required String groupId,
    required PlatformFile file,
  }) async {
    final String ext = file.name.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
    final Reference ref = _storage.ref('groupPhotos/$groupId.$ext');
    final SettableMetadata metadata = SettableMetadata(
      contentType: ext == 'png' ? 'image/png' : 'image/jpeg',
    );
    UploadTask task;
    if (file.bytes != null) {
      task = ref.putData(file.bytes!, metadata);
    } else if (file.path != null) {
      task = ref.putFile(File(file.path!), metadata);
    } else {
      throw Exception('No image payload found');
    }
    await task;
    return ref.getDownloadURL();
  }

  @override
  Future<void> setGroupPhotoUrl({
    required String groupId,
    required String? photoUrl,
  }) async {
    await _groupRef(
      groupId,
    ).set(<String, dynamic>{'photoUrl': photoUrl}, SetOptions(merge: true));
  }

  @override
  Future<void> pinMessage({
    required String groupId,
    required String? messageId,
  }) async {
    try {
      await _groupRef(groupId).set(<String, dynamic>{
        'pinnedMessageId': messageId,
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to pin message: $e');
    }
  }

  @override
  Future<void> deleteFile({
    required String groupId,
    required String fileId,
  }) async {
    await _groupRef(groupId).collection('files').doc(fileId).delete();
  }
}
