import 'package:cloud_firestore/cloud_firestore.dart';

enum GroupType {
  general('general'),
  subject('subject');

  const GroupType(this.id);
  final String id;

  static GroupType fromId(String? id) {
    return GroupType.values.firstWhere(
      (GroupType type) => type.id == id,
      orElse: () => GroupType.general,
    );
  }
}

enum MessageType {
  text('text'),
  image('image'),
  pdf('pdf'),
  video('video'),
  link('link'),
  system('system');

  const MessageType(this.id);
  final String id;

  static MessageType fromId(String? id) {
    return MessageType.values.firstWhere(
      (MessageType type) => type.id == id,
      orElse: () => MessageType.text,
    );
  }
}

class GroupModel {
  const GroupModel({
    required this.id,
    required this.name,
    required this.type,
    required this.dept,
    required this.batch,
    required this.createdByUid,
    required this.createdAt,
    this.description,
  });

  final String id;
  final String name;
  final GroupType type;
  final String dept;
  final String batch;
  final String createdByUid;
  final DateTime? createdAt;
  final String? description;

  factory GroupModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
    return GroupModel(
      id: doc.id,
      name: data['name'] as String? ?? '',
      type: GroupType.fromId(data['type'] as String?),
      dept: data['dept'] as String? ?? '',
      batch: data['batch'] as String? ?? '',
      createdByUid: data['createdByUid'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      description: data['description'] as String?,
    );
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.uid,
    required this.senderName,
    required this.senderPhoto,
    required this.type,
    required this.content,
    required this.timestamp,
    this.fileUrl,
    this.fileName,
    this.fileType,
    this.fileSize,
    this.thumbnailUrl,
    this.reactions = const <String, dynamic>{},
    this.isDeleted = false,
    this.replyTo,
    this.isForwarded = false,
    this.status = 'sent',
  });

  final String id;
  final String uid;
  final String senderName;
  final String? senderPhoto;
  final MessageType type;
  final String content;
  final DateTime? timestamp;
  final String? fileUrl;
  final String? fileName;
  final String? fileType;
  final int? fileSize;
  final String? thumbnailUrl;
  final Map<String, dynamic> reactions;
  final bool isDeleted;
  final Map<String, dynamic>? replyTo;
  final bool isForwarded;
  final String status; // 'sending' | 'sent' | 'failed'

  factory ChatMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
    return ChatMessage(
      id: doc.id,
      uid: data['uid'] as String? ?? '',
      senderName: data['senderName'] as String? ?? 'Unknown',
      senderPhoto: data['senderPhoto'] as String?,
      type: MessageType.fromId(data['type'] as String?),
      content: data['content'] as String? ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate(),
      fileUrl: data['fileUrl'] as String?,
      fileName: data['fileName'] as String?,
      fileType: data['fileType'] as String?,
      fileSize: (data['fileSize'] as num?)?.toInt(),
      thumbnailUrl: data['thumbnailUrl'] as String?,
      reactions: (data['reactions'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      isDeleted: data['isDeleted'] as bool? ?? false,
      replyTo: data['replyTo'] as Map<String, dynamic>?,
      isForwarded: data['isForwarded'] as bool? ?? false,
      status: data['status'] as String? ?? 'sent',
    );
  }
}

class GroupFile {
  const GroupFile({
    required this.id,
    required this.uploadedByUid,
    required this.fileName,
    required this.fileUrl,
    required this.fileType,
    this.fileSize,
    required this.uploadedAt,
  });

  final String id;
  final String uploadedByUid;
  final String fileName;
  final String fileUrl;
  final String fileType;
  final int? fileSize;
  final DateTime? uploadedAt;

  factory GroupFile.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
    return GroupFile(
      id: doc.id,
      uploadedByUid: data['uploadedByUid'] as String? ?? '',
      fileName: data['fileName'] as String? ?? '',
      fileUrl: data['fileUrl'] as String? ?? '',
      fileType: data['fileType'] as String? ?? 'pdf',
      fileSize: (data['fileSize'] as num?)?.toInt(),
      uploadedAt: (data['uploadedAt'] as Timestamp?)?.toDate(),
    );
  }
}