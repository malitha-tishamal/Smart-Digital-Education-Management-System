import 'package:cloud_firestore/cloud_firestore.dart';

class MeetingModel {
  final String id;
  final String title;
  final String academicYear;
  final String zoomLink;
  final DateTime? scheduledTime;
  final DateTime? expiryTime;
  final int duration;
  final String description;
  final List<String> students;
  final List<String> joinedStudents;
  final Map<String, dynamic> joinedTimes;
  final String status; // 'live', 'upcoming', 'past', 'expired'
  final String teacherId;
  final String teacherName;
  final String teacherEmail;
  final String? teacherProfileImageUrl;

  MeetingModel({
    required this.id,
    required this.title,
    this.academicYear = 'N/A',
    required this.zoomLink,
    this.scheduledTime,
    this.expiryTime,
    this.duration = 60,
    this.description = '',
    this.students = const [],
    this.joinedStudents = const [],
    this.joinedTimes = const {},
    this.status = 'upcoming',
    required this.teacherId,
    this.teacherName = 'Unknown Teacher',
    this.teacherEmail = '',
    this.teacherProfileImageUrl,
  });

  bool get isLive {
    if (status == 'live') return true;
    if (scheduledTime == null) return false;
    final now = DateTime.now();
    final end = scheduledTime!.add(Duration(minutes: duration));
    return now.isAfter(scheduledTime!) && now.isBefore(end);
  }

  bool get isExpired {
    if (expiryTime != null && DateTime.now().isAfter(expiryTime!)) return true;
    return status == 'expired';
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'academicYear': academicYear,
      'zoomLink': zoomLink,
      if (scheduledTime != null) 'scheduledTime': Timestamp.fromDate(scheduledTime!),
      if (expiryTime != null) 'expiryTime': Timestamp.fromDate(expiryTime!),
      'duration': duration,
      'description': description,
      'students': students,
      'joinedStudents': joinedStudents,
      'joinedTimes': joinedTimes,
      'status': status,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'teacherEmail': teacherEmail,
      if (teacherProfileImageUrl != null) 'teacherProfileImageUrl': teacherProfileImageUrl,
    };
  }

  factory MeetingModel.fromMap(String id, Map<String, dynamic> map) {
    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return MeetingModel(
      id: id,
      title: map['title'] ?? 'Untitled Meeting',
      academicYear: map['academicYear'] ?? 'N/A',
      zoomLink: map['zoomLink'] ?? '',
      scheduledTime: parseDate(map['scheduledTime']),
      expiryTime: parseDate(map['expiryTime']),
      duration: (map['duration'] as num?)?.toInt() ?? 60,
      description: map['description'] ?? '',
      students: List<String>.from(map['students'] ?? []),
      joinedStudents: List<String>.from(map['joinedStudents'] ?? []),
      joinedTimes: Map<String, dynamic>.from(map['joinedTimes'] ?? {}),
      status: map['status'] ?? 'upcoming',
      teacherId: map['teacherId'] ?? '',
      teacherName: map['teacherName'] ?? 'Unknown Teacher',
      teacherEmail: map['teacherEmail'] ?? '',
      teacherProfileImageUrl: map['teacherProfileImageUrl'] as String?,
    );
  }

  factory MeetingModel.fromFirestore(DocumentSnapshot doc) {
    return MeetingModel.fromMap(doc.id, doc.data() as Map<String, dynamic>? ?? {});
  }
}
