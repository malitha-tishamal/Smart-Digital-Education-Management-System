import 'package:cloud_firestore/cloud_firestore.dart';

class EnrollmentModel {
  final String id;
  final String studentId;
  final String classId; // Teacher's UID
  final DateTime? assignedDate;
  final DateTime? expiryDate;
  final bool freeAccess;
  final bool paymentApproved;
  final DateTime? trialStart;
  final DateTime? trialEnd;
  final String status; // 'active', 'trial', 'expired'
  final String currentMonth;
  final String? paymentStatus;
  final String? transactionId;
  final DateTime? lastPaymentDate;
  final String? paymentMonth;

  EnrollmentModel({
    required this.id,
    required this.studentId,
    required this.classId,
    this.assignedDate,
    this.expiryDate,
    this.freeAccess = false,
    this.paymentApproved = false,
    this.trialStart,
    this.trialEnd,
    this.status = 'trial',
    this.currentMonth = '',
    this.paymentStatus,
    this.transactionId,
    this.lastPaymentDate,
    this.paymentMonth,
  });

  bool get isActive => status == 'active';
  bool get isTrial => status == 'trial';
  bool get isExpired => status == 'expired';

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'classId': classId,
      if (assignedDate != null) 'assignedDate': Timestamp.fromDate(assignedDate!),
      if (expiryDate != null) 'expiryDate': Timestamp.fromDate(expiryDate!),
      'freeAccess': freeAccess,
      'paymentApproved': paymentApproved,
      if (trialStart != null) 'trialStart': Timestamp.fromDate(trialStart!),
      if (trialEnd != null) 'trialEnd': Timestamp.fromDate(trialEnd!),
      'status': status,
      'currentMonth': currentMonth,
      if (paymentStatus != null) 'paymentStatus': paymentStatus,
      if (transactionId != null) 'transactionId': transactionId,
      if (lastPaymentDate != null) 'lastPaymentDate': Timestamp.fromDate(lastPaymentDate!),
      if (paymentMonth != null) 'paymentMonth': paymentMonth,
    };
  }

  factory EnrollmentModel.fromMap(String id, Map<String, dynamic> map) {
    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return EnrollmentModel(
      id: id,
      studentId: map['studentId'] ?? '',
      classId: map['classId'] ?? '',
      assignedDate: parseDate(map['assignedDate']),
      expiryDate: parseDate(map['expiryDate']),
      freeAccess: map['freeAccess'] ?? false,
      paymentApproved: map['paymentApproved'] ?? false,
      trialStart: parseDate(map['trialStart']),
      trialEnd: parseDate(map['trialEnd']),
      status: map['status'] ?? 'trial',
      currentMonth: map['currentMonth'] ?? '',
      paymentStatus: map['paymentStatus'] as String?,
      transactionId: map['transactionId'] as String?,
      lastPaymentDate: parseDate(map['lastPaymentDate']),
      paymentMonth: map['paymentMonth'] as String?,
    );
  }

  factory EnrollmentModel.fromFirestore(DocumentSnapshot doc) {
    return EnrollmentModel.fromMap(doc.id, doc.data() as Map<String, dynamic>? ?? {});
  }
}
