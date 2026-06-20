import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/college.dart';

class CollegeRepository {
  CollegeRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<List<College>> getColleges() async {
    final snapshot = await _firestore
        .collection('colleges')
        .get(const GetOptions(source: Source.server));
    return snapshot.docs
        .map((doc) => College.fromMap(doc.id, doc.data()))
        .toList();
  }
}
