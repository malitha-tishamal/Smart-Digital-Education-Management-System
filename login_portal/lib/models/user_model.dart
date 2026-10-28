import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String email;
  final String name;
  final String nic;
  final String mobile;
  final String role;             // 'admin', 'teacher', 'user' (student)
  final String stream;           // 'Science', 'Commerce', 'Arts', 'Technology'
  final List<String> subjects;
  final String status;           // 'Approved', 'pending', 'Locked', 'Disabled'
  final String alYear;  
  final String studentId;
  final String? profileImageUrl;
  final int failedLoginAttempts;
  final DateTime? lockoutUntil;
  final DateTime? lastLoginAt;
  final DateTime? createdAt;

  AppUser({
    required this.uid,
    required this.email,
    required this.name,
    required this.nic,
    required this.mobile,
    required this.role,
    required this.stream,
    required this.subjects,
    required this.status,
    this.alYear = '', 
    this.studentId = '',
    this.profileImageUrl,
    this.failedLoginAttempts = 0,
    this.lockoutUntil,
    this.lastLoginAt,
    this.createdAt,
  });

  bool get isAdmin => role.toLowerCase() == 'admin';
  bool get isTeacher => role.toLowerCase() == 'teacher';
  bool get isStudent => role.toLowerCase() == 'user' || role.toLowerCase() == 'student';
  bool get isApproved => status.toLowerCase() == 'approved';
  bool get isLocked => status.toLowerCase() == 'locked';
  bool get isPending => status.toLowerCase() == 'pending';

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'nic': nic,
      'mobile': mobile,
      'role': role,
      'stream': stream,
      'subjects': subjects,
      'status': status,
      'alYear': alYear,  
      'studentId': studentId,
      if (profileImageUrl != null) 'profileImageUrl': profileImageUrl,
      'failedLoginAttempts': failedLoginAttempts,
      if (lockoutUntil != null) 'lockoutUntil': Timestamp.fromDate(lockoutUntil!),
      if (lastLoginAt != null) 'lastLoginAt': Timestamp.fromDate(lastLoginAt!),
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
    };
  }

  factory AppUser.fromMap(String uid, Map<String, dynamic> map) {
    DateTime? parseTimestamp(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return AppUser(
      uid: uid,
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      nic: map['nic'] ?? '',
      mobile: map['mobile'] ?? '',
      role: map['role'] ?? 'user',
      stream: map['stream'] ?? '',
      subjects: List<String>.from(map['subjects'] ?? []),
      status: map['status'] ?? 'pending',
      alYear: map['alYear'] ?? '', 
      studentId: map['studentId'] ?? '',
      profileImageUrl: map['profileImageUrl'] as String?,
      failedLoginAttempts: (map['failedLoginAttempts'] as num?)?.toInt() ?? 0,
      lockoutUntil: parseTimestamp(map['lockoutUntil']),
      lastLoginAt: parseTimestamp(map['lastLoginAt']),
      createdAt: parseTimestamp(map['createdAt']),
    );
  }

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AppUser.fromMap(doc.id, data);
  }

  AppUser copyWith({
    String? uid,
    String? email,
    String? name,
    String? nic,
    String? mobile,
    String? role,
    String? stream,
    List<String>? subjects,
    String? status,
    String? alYear,
    String? studentId,
    String? profileImageUrl,
    int? failedLoginAttempts,
    DateTime? lockoutUntil,
    DateTime? lastLoginAt,
    DateTime? createdAt,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      nic: nic ?? this.nic,
      mobile: mobile ?? this.mobile,
      role: role ?? this.role,
      stream: stream ?? this.stream,
      subjects: subjects ?? this.subjects,
      status: status ?? this.status,
      alYear: alYear ?? this.alYear,
      studentId: studentId ?? this.studentId,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      failedLoginAttempts: failedLoginAttempts ?? this.failedLoginAttempts,
      lockoutUntil: lockoutUntil ?? this.lockoutUntil,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Alias for UserModel
typedef UserModel = AppUser;
