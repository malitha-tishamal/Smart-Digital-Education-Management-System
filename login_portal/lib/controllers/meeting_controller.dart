import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/meeting_model.dart';
import '../core/app_config.dart';

class MeetingController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _meetingsCollection =>
      _firestore.collection(AppConfig.zoomMeetingsCollection);

  /// Stream all meetings ordered by scheduledTime
  Stream<List<MeetingModel>> streamAllMeetings() {
    return _meetingsCollection
        .orderBy('scheduledTime', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MeetingModel.fromFirestore(doc))
            .toList());
  }

  /// Stream meetings created by a specific teacher
  Stream<List<MeetingModel>> streamTeacherMeetings(String teacherId) {
    return _meetingsCollection
        .where('teacherId', isEqualTo: teacherId)
        .orderBy('scheduledTime', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MeetingModel.fromFirestore(doc))
            .toList());
  }

  /// Create a new Zoom meeting
  Future<String> createMeeting(MeetingModel meeting) async {
    final docRef = await _meetingsCollection.add(meeting.toMap());
    return docRef.id;
  }

  /// Update an existing Zoom meeting
  Future<void> updateMeeting(String meetingId, Map<String, dynamic> updateData) async {
    await _meetingsCollection.doc(meetingId).update(updateData);
  }

  /// Delete a Zoom meeting
  Future<void> deleteMeeting(String meetingId) async {
    await _meetingsCollection.doc(meetingId).delete();
  }

  /// Record a student joining a meeting
  Future<void> recordStudentJoin(String meetingId, String studentId) async {
    await _meetingsCollection.doc(meetingId).update({
      'joinedStudents': FieldValue.arrayUnion([studentId]),
      'joinedTimes.$studentId': Timestamp.now(),
    });
  }
}
