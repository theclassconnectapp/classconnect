import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/app_user.dart';
import '../models/group_models.dart';
import '../models/user_role.dart';

class GroupRepository {
  GroupRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _groups =>
      _firestore.collection('groups');

  DocumentReference<Map<String, dynamic>> _groupRef(String groupId) =>
      _groups.doc(groupId);

  Stream<DocumentSnapshot<Map<String, dynamic>>> streamGroupDoc(String groupId) =>
      _groupRef(groupId).snapshots();

  String generalGroupId({required String dept, required String batch}) =>
      'general_${dept}_$batch'.toLowerCase().replaceAll(' ', '_');

  Future<void> ensureGeneralGroupExists({
    required String dept,
    required String batch,
    required String advisorUid,
    required String advisorName,
  }) async {
    final DocumentReference<Map<String, dynamic>> ref =
        _groupRef(generalGroupId(dept: dept, batch: batch));
    await _firestore.runTransaction((Transaction txn) async {
      final DocumentSnapshot<Map<String, dynamic>> snap = await txn.get(ref);
      final Map<String, dynamic> base = <String, dynamic>{
        'name': '$dept $batch - General',
        'type': GroupType.general.id,
        'dept': dept,
        'batch': batch,
        'createdByUid': advisorUid,
        'createdByName': advisorName,
        'createdAt': snap.exists
            ? (snap.data()?['createdAt'] ?? FieldValue.serverTimestamp())
            : FieldValue.serverTimestamp(),
        'description': 'General class group',
        'admins': <String>[advisorUid],
        'mutedMembers': <String>[],
        'onlyAdminsCanMessage': false,
        'photoUrl': null,
        'pinnedMessageId': null,
      };
      txn.set(ref, base, SetOptions(merge: true));
    });
  }

  Future<void> addMember({
    required String groupId,
    required AppUser user,
  }) async {
    final DocumentReference<Map<String, dynamic>> group = _groupRef(groupId);
    final DocumentReference<Map<String, dynamic>> member =
        group.collection('members').doc(user.uid);
    final DocumentReference<Map<String, dynamic>> state =
        group.collection('states').doc(user.uid);
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
  }

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

  Future<void> syncMembership(AppUser user) async {
    if (user.dept == null || user.batch == null) {
      return;
    }
    if (user.role == UserRole.advisor) {
      await ensureGeneralGroupExists(
        dept: user.dept!,
        batch: user.batch!,
        advisorUid: user.uid,
        advisorName: user.name,
      );
    }
    await addMember(
      groupId: generalGroupId(dept: user.dept!, batch: user.batch!),
      user: user,
    );
  }

  Future<void> createSubjectGroup({
    required String name,
    required String dept,
    required String batch,
    required String createdByUid,
    required String createdByName,
    required String description,
  }) async {
    final DocumentReference<Map<String, dynamic>> group = _groups.doc();
    final DocumentReference<Map<String, dynamic>> member =
        group.collection('members').doc(createdByUid);
    final DocumentReference<Map<String, dynamic>> state =
        group.collection('states').doc(createdByUid);
    final WriteBatch batchWrite = _firestore.batch();
    batchWrite.set(group, <String, dynamic>{
      'name': name.trim(),
      'type': GroupType.subject.id,
      'dept': dept,
      'batch': batch,
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

  Stream<QuerySnapshot<Map<String, dynamic>>> streamGroupsForUser(AppUser user) {
    switch (user.role) {
      case UserRole.hod:
        return _groups.snapshots();
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
        return _groups.snapshots();
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamGroupsInFolder({
    required String dept,
    required String batch,
  }) {
    return _groups
        .where('dept', isEqualTo: dept)
        .where('batch', isEqualTo: batch)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamMembers(String groupId) {
    return _groupRef(groupId)
        .collection('members')
        .orderBy('joinedAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamMessages(String groupId) {
    return _groupRef(groupId)
        .collection('messages')
        .orderBy('timestamp')
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamFiles(String groupId) {
    return _groupRef(groupId)
        .collection('files')
        .orderBy('uploadedAt', descending: true)
        .snapshots();
  }

  Future<void> sendTextMessage({
    required String groupId,
    required AppUser sender,
    required String text,
    Map<String, dynamic>? replyTo,
    bool isForwarded = false,
  }) async {
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
    });
    await _groupRef(groupId).set(<String, dynamic>{
      'lastMessageText': clean,
      'lastMessageTime': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<String> _uploadToStorage({
    required String groupId,
    required String fileName,
    required String mimeType,
    String? filePath,
    Uint8List? bytes,
  }) async {
    final String safeName = fileName.replaceAll(' ', '_');
    final String path =
        'groups/$groupId/files/${DateTime.now().millisecondsSinceEpoch}_$safeName';
    final Reference ref = _storage.ref(path);
    final SettableMetadata metadata = SettableMetadata(contentType: mimeType);
    UploadTask task;
    if (bytes != null) {
      task = ref.putData(bytes, metadata);
    } else if (filePath != null) {
      task = ref.putFile(File(filePath), metadata);
    } else {
      throw Exception('Missing file bytes/path');
    }
    await task;
    return ref.getDownloadURL();
  }

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
    final String url = await _uploadToStorage(
      groupId: groupId,
      fileName: fileName,
      mimeType: mimeType,
      filePath: localPath,
      bytes: bytes,
    );

    final WriteBatch write = _firestore.batch();
    final DocumentReference<Map<String, dynamic>> msgRef =
        _groupRef(groupId).collection('messages').doc();
    final DocumentReference<Map<String, dynamic>> fileRef =
        _groupRef(groupId).collection('files').doc();

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
  }

  Future<void> markGroupSeen({
    required String groupId,
    required String uid,
  }) async {
    await _groupRef(groupId).collection('states').doc(uid).set(<String, dynamic>{
      'uid': uid,
      'lastSeenAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<int> unreadCountFor({
    required String groupId,
    required String uid,
  }) async {
    final DocumentSnapshot<Map<String, dynamic>> state =
        await _groupRef(groupId).collection('states').doc(uid).get();
    final Timestamp? seen = state.data()?['lastSeenAt'] as Timestamp?;
    Query<Map<String, dynamic>> q =
        _groupRef(groupId).collection('messages').where('uid', isNotEqualTo: uid);
    if (seen != null) {
      q = q.where('timestamp', isGreaterThan: seen);
    }
    final AggregateQuerySnapshot count = await q.count().get();
    return count.count ?? 0;
  }

  Future<void> reactToMessage({
    required String groupId,
    required String messageId,
    required String uid,
    required String reaction,
  }) async {
    await _groupRef(groupId)
        .collection('messages')
        .doc(messageId)
        .set(<String, dynamic>{'reactions.$uid': reaction}, SetOptions(merge: true));
  }

  Future<void> forwardMessage({
    required String sourceGroupId,
    required String messageId,
    required String targetGroupId,
    required AppUser sender,
  }) async {
    final DocumentSnapshot<Map<String, dynamic>> source =
        await _groupRef(sourceGroupId).collection('messages').doc(messageId).get();
    if (!source.exists) {
      return;
    }
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

  Future<void> deleteMessage({
    required String groupId,
    required String messageId,
    required String deletedByUid,
  }) async {
    await _groupRef(groupId).collection('messages').doc(messageId).set(
      <String, dynamic>{
        'isDeleted': true,
        'deletedByUid': deletedByUid,
        'deletedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> setGroupAdmins({
    required String groupId,
    required List<String> adminUids,
  }) async {
    await _groupRef(groupId).set(<String, dynamic>{
      'admins': adminUids.toSet().toList(),
    }, SetOptions(merge: true));
  }

  Future<void> setMutedMembers({
    required String groupId,
    required List<String> mutedUids,
  }) async {
    await _groupRef(groupId).set(<String, dynamic>{
      'mutedMembers': mutedUids.toSet().toList(),
    }, SetOptions(merge: true));
  }

  Future<void> setOnlyAdminsCanMessage({
    required String groupId,
    required bool enabled,
  }) async {
    await _groupRef(groupId).set(<String, dynamic>{
      'onlyAdminsCanMessage': enabled,
    }, SetOptions(merge: true));
  }

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

  Future<void> setGroupPhotoUrl({
    required String groupId,
    required String? photoUrl,
  }) async {
    await _groupRef(groupId).set(<String, dynamic>{
      'photoUrl': photoUrl,
    }, SetOptions(merge: true));
  }

  Future<void> pinMessage({
    required String groupId,
    required String? messageId,
  }) async {
    await _groupRef(groupId).set(<String, dynamic>{
      'pinnedMessageId': messageId,
    }, SetOptions(merge: true));
  }

  Future<void> deleteFile({
    required String groupId,
    required String fileId,
  }) async {
    await _groupRef(groupId).collection('files').doc(fileId).delete();
  }
}

