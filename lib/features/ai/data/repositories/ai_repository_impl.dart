import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../domain/entities/ai_session.dart';
import '../../domain/repositories/ai_repository.dart';
import '../../presentation/cubit/ai_state.dart';

class AiRepositoryImpl implements AiRepository {
  AiRepositoryImpl({required ApiClient apiClient, FirebaseFirestore? firestore})
    : _apiClient = apiClient,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final ApiClient _apiClient;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _sessionsRef(String uid) =>
      _firestore.collection('users').doc(uid).collection('aiSessions');

  CollectionReference<Map<String, dynamic>> _messagesRef({
    required String uid,
    required String sessionId,
  }) => _sessionsRef(uid).doc(sessionId).collection('messages');

  @override
  Future<String> generateResponse(String prompt) async {
    final Object? response = await _apiClient.post(
      '/api/v1/ai/generate',
      body: <String, Object?>{'prompt': prompt},
    );

    if (response is Map<String, Object?>) {
      final Object? data = response['data'];
      if (data is String) {
        return data;
      }
    }

    throw const ApiException(
      statusCode: 0,
      code: 'invalid_response',
      message: 'Backend returned an unexpected response.',
    );
  }

  @override
  Future<String> createSession({
    required String uid,
    required String scope,
    required String scopeId,
    required String firstMessage,
  }) async {
    final DocumentReference<Map<String, dynamic>> doc = _sessionsRef(uid).doc();
    final String title = firstMessage.trim().length > 50
        ? firstMessage.trim().substring(0, 50)
        : firstMessage.trim();
    await doc.set(<String, dynamic>{
      'title': title.isEmpty ? 'New conversation' : title,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'scope': scope,
      'scopeId': scopeId,
      'messageCount': 0,
    });
    return doc.id;
  }

  @override
  Future<void> saveMessage({
    required String uid,
    required String sessionId,
    required AiMessage message,
  }) async {
    final WriteBatch batch = _firestore.batch();
    final DocumentReference<Map<String, dynamic>> sessionRef = _sessionsRef(
      uid,
    ).doc(sessionId);
    final DocumentReference<Map<String, dynamic>> messageRef = _messagesRef(
      uid: uid,
      sessionId: sessionId,
    ).doc();

    batch.set(messageRef, <String, dynamic>{
      'text': message.text,
      'isUser': message.isUser,
      'isError': message.isError,
      'timestamp': Timestamp.fromDate(message.timestamp),
    });
    batch.set(sessionRef, <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
      'messageCount': FieldValue.increment(1),
    }, SetOptions(merge: true));
    await batch.commit();
  }

  @override
  Stream<List<AiSession>> streamSessions({required String uid}) {
    return _sessionsRef(uid)
        .orderBy('updatedAt', descending: true)
        .limit(30)
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, dynamic>> snapshot) => snapshot.docs.map((
            QueryDocumentSnapshot<Map<String, dynamic>> doc,
          ) {
            final Map<String, dynamic> data = doc.data();
            final Timestamp? createdAt = data['createdAt'] as Timestamp?;
            final Timestamp? updatedAt = data['updatedAt'] as Timestamp?;
            return AiSession(
              id: doc.id,
              title: data['title'] as String? ?? 'New conversation',
              createdAt: createdAt?.toDate() ?? DateTime.now(),
              updatedAt: updatedAt?.toDate() ?? DateTime.now(),
              scope: data['scope'] as String? ?? '',
              scopeId: data['scopeId'] as String? ?? '',
              messageCount: (data['messageCount'] as num?)?.toInt() ?? 0,
            );
          }).toList(),
        );
  }

  @override
  Future<List<AiMessage>> loadMessages({
    required String uid,
    required String sessionId,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _messagesRef(
      uid: uid,
      sessionId: sessionId,
    ).orderBy('timestamp').get();

    return snapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
      final Map<String, dynamic> data = doc.data();
      final Timestamp? timestamp = data['timestamp'] as Timestamp?;
      return AiMessage(
        text: data['text'] as String? ?? '',
        isUser: data['isUser'] as bool? ?? false,
        isError: data['isError'] as bool? ?? false,
        timestamp: timestamp?.toDate() ?? DateTime.now(),
      );
    }).toList();
  }
}
