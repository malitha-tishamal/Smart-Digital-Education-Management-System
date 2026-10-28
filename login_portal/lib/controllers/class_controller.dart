import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/enrollment_model.dart';
import '../models/class_model.dart';
import '../core/app_config.dart';

class ClassController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _enrollmentsCollection =>
      _firestore.collection(AppConfig.enrollmentsCollection);
  CollectionReference get _usersCollection =>
      _firestore.collection(AppConfig.usersCollection);

  /// Stream all teachers (which represent classes/teachers in Eduwide)
  Stream<List<TeacherClassModel>> streamTeachers() {
    return _usersCollection
        .where('role', isEqualTo: 'teacher')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TeacherClassModel.fromMap(
                doc.id, doc.data() as Map<String, dynamic>))
            .toList());
  }

  /// Update teacher payment & gateway settings
  Future<void> updatePaymentSettings({
    required String teacherId,
    required bool paymentRequired,
    required double monthlyFee,
    required bool gatewayEnabled,
    required String gatewayLink,
    required double gatewayAmount,
  }) async {
    await _usersCollection.doc(teacherId).update({
      'paymentRequired': paymentRequired,
      'monthlyFee': monthlyFee,
      'paymentGateway': {
        'enabled': gatewayEnabled,
        'link': gatewayLink,
        'amount': gatewayAmount,
      },
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Enroll a student in a class
  Future<void> enrollStudent({
    required String studentId,
    required String teacherId,
    bool isFreePeriod = false,
  }) async {
    final now = DateTime.now();
    final trialEnd = now.add(const Duration(days: 7));
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    final expiry = isFreePeriod ? trialEnd : lastDayOfMonth;

    await _enrollmentsCollection.add({
      'studentId': studentId,
      'classId': teacherId,
      'assignedDate': Timestamp.fromDate(now),
      'expiryDate': Timestamp.fromDate(expiry),
      'freeAccess': isFreePeriod,
      'paymentApproved': false,
      'trialStart': Timestamp.fromDate(now),
      'trialEnd': Timestamp.fromDate(trialEnd),
      'status': isFreePeriod ? 'trial' : 'expired',
      'currentMonth': '${now.year}-${now.month.toString().padLeft(2, '0')}',
    });
  }

  /// Remove a student from a class
  Future<void> removeStudentFromClass(String enrollmentId) async {
    await _enrollmentsCollection.doc(enrollmentId).delete();
  }

  /// Mark payment as approved for an enrollment
  Future<void> approvePayment(String enrollmentId) async {
    final now = DateTime.now();
    final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final lastDay = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    await _enrollmentsCollection.doc(enrollmentId).update({
      'paymentApproved': true,
      'freeAccess': false,
      'expiryDate': Timestamp.fromDate(lastDay),
      'status': 'active',
      'currentMonth': month,
      'paymentStatus': 'paid',
      'transactionId': 'manual_mark_${DateTime.now().millisecondsSinceEpoch}',
      'lastPaymentDate': Timestamp.fromDate(now),
      'paymentMonth': month,
    });
  }

  /// Stream enrollments for a specific class/teacher
  Stream<List<EnrollmentModel>> streamClassEnrollments(String teacherId) {
    return _enrollmentsCollection
        .where('classId', isEqualTo: teacherId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => EnrollmentModel.fromFirestore(doc))
            .toList());
  }

  /// Stream classes a specific student is enrolled in
  Stream<List<EnrollmentModel>> streamStudentEnrollments(String studentId) {
    return _enrollmentsCollection
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => EnrollmentModel.fromFirestore(doc))
            .toList());
  }
}
