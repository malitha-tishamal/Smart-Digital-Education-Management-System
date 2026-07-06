class AppUser {
  final String uid;
  final String email;
  final String name;
  final String nic;
  final String mobile;
  final String role;             
  final String stream;           
  final List<String> subjects;
  final String status;
  final String alYear;  
  final String studentId; // 👈 new        

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
  });

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
    };
  }

  factory AppUser.fromMap(String uid, Map<String, dynamic> map) {
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
    );
  }
}