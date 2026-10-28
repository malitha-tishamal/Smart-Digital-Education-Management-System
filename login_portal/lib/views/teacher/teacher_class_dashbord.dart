import '../../core/app_config.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../core/app_colors.dart';
import '../auth/login_screen.dart';
import 'teacher_drawer.dart';

class ZoomMeetingDashboard extends StatefulWidget {
  const ZoomMeetingDashboard({super.key});

  @override
  State<ZoomMeetingDashboard> createState() => _ZoomMeetingDashboardState();
}

class _ZoomMeetingDashboardState extends State<ZoomMeetingDashboard> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isLoading = true;
  String _teacherName = 'Teacher';
  String _teacherEmail = '';
  String _profileImageUrl = '';
  String _teacherStream = '';
  List<String> _teacherSubjects = [];
  
  List<Map<String, dynamic>> _upcomingMeetings = [];
  List<Map<String, dynamic>> _activeMeetings = [];
  List<Map<String, dynamic>> _expiredMeetings = [];
  
  Map<String, Map<String, dynamic>> _enrolledStudentsByYear = {};
  List<String> _academicYears = [];
  Map<String, Map<String, dynamic>> _studentDetails = {};

  String get _defaultProfileImageUrl => AppConfig.defaultProfileImageUrl;

  @override
  void initState() {
    super.initState();
    _loadTeacherData();
  }

  Future<void> _loadTeacherData() async {
    setState(() => _isLoading = true);

    final user = _auth.currentUser;
    if (user == null) {
      _goToLogin();
      return;
    }

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) {
        _goToLogin();
        return;
      }

      final data = doc.data() as Map<String, dynamic>;
      _teacherName = data['name'] ?? 'Teacher';
      _teacherEmail = data['email'] ?? user.email ?? 'teacher@example.com';
      _profileImageUrl = data['profileImageUrl'] ?? _defaultProfileImageUrl;
      _teacherStream = data['stream'] ?? '';
      _teacherSubjects = List<String>.from(data['subjects'] ?? []);

      await Future.wait([
        _fetchEnrolledStudents(),
        _fetchZoomMeetings(),
      ]);
    } catch (e) {
      print('Error loading teacher data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchEnrolledStudents() async {
    try {
      final teacherId = _auth.currentUser?.uid;
      if (teacherId == null) return;

      final enrollmentsSnapshot = await _firestore
          .collection('enrollments')
          .where('classId', isEqualTo: teacherId)
          .where('status', isEqualTo: 'active')
          .get();

      final usersSnapshot = await _firestore.collection('users').get();
      final usersMap = <String, Map<String, dynamic>>{};
      
      for (var doc in usersSnapshot.docs) {
        final userData = doc.data() as Map<String, dynamic>;
        if (userData['role'] == 'user') {
          usersMap[doc.id] = {
            'id': doc.id,
            'name': userData['name'] ?? 'Unknown',
            'stream': userData['stream'] ?? '',
            'subjects': List<String>.from(userData['subjects'] ?? []),
            'alYear': userData['alYear'] ?? '2024',
            'studentId': userData['studentId'] ?? '',
            'email': userData['email'] ?? '',
            'mobile': userData['mobile'] ?? '',
            'nic': userData['nic'] ?? '',
          };
          _studentDetails[doc.id] = usersMap[doc.id]!;
        }
      }

      _enrolledStudentsByYear = {};
      
      for (var enrollment in enrollmentsSnapshot.docs) {
        final enrollmentData = enrollment.data() as Map<String, dynamic>;
        final studentId = enrollmentData['studentId'] as String?;
        
        if (studentId != null && usersMap.containsKey(studentId)) {
          final studentData = usersMap[studentId]!;
          final studentSubjects = List<String>.from(studentData['subjects']);
          bool hasMatchingSubject = _teacherSubjects.any((subject) => studentSubjects.contains(subject));
          bool hasMatchingStream = _teacherStream.isNotEmpty && studentData['stream'] == _teacherStream;
          
          if (hasMatchingSubject || hasMatchingStream) {
            final year = studentData['alYear'] ?? '2024';
            if (!_enrolledStudentsByYear.containsKey(year)) {
              _enrolledStudentsByYear[year] = {};
            }
            _enrolledStudentsByYear[year]![studentId] = studentData;
          }
        }
      }

      _academicYears = _enrolledStudentsByYear.keys.toList()..sort((a, b) => b.compareTo(a));
      setState(() {});
    } catch (e) {
      print('Error fetching enrolled students: $e');
    }
  }

  Future<void> _fetchZoomMeetings() async {
    try {
      final teacherId = _auth.currentUser?.uid;
      if (teacherId == null) return;

      final meetingsSnapshot = await _firestore
          .collection('zoomMeetings')
          .where('teacherId', isEqualTo: teacherId)
          .get();

      final now = DateTime.now();
      
      _upcomingMeetings.clear();
      _activeMeetings.clear();
      _expiredMeetings.clear();

      for (var doc in meetingsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final scheduledTime = (data['scheduledTime'] as Timestamp?)?.toDate();
        final expiryTime = (data['expiryTime'] as Timestamp?)?.toDate();
        final duration = data['duration'] ?? 60;
        final status = data['status'] ?? 'upcoming';
        
        DateTime? endTime;
        if (scheduledTime != null) {
          endTime = scheduledTime.add(Duration(minutes: duration));
        }
        
        bool isExpired = false;
        if (expiryTime != null && now.isAfter(expiryTime)) {
          isExpired = true;
          if (status != 'expired' && status != 'disabled') {
            await _firestore.collection('zoomMeetings').doc(doc.id).update({
              'status': 'expired',
            });
          }
        }
        
        final meeting = {
          'id': doc.id,
          'title': data['title'] ?? 'Zoom Meeting',
          'academicYear': data['academicYear'] ?? '2024',
          'zoomLink': data['zoomLink'] ?? '',
          'scheduledTime': scheduledTime,
          'expiryTime': expiryTime,
          'duration': duration,
          'description': data['description'] ?? '',
          'students': List<String>.from(data['students'] ?? []),
          'joinedStudents': List<String>.from(data['joinedStudents'] ?? []),
          'joinedTimes': Map<String, dynamic>.from(data['joinedTimes'] ?? {}),
          'status': isExpired ? 'expired' : status,
          'teacherName': data['teacherName'] ?? _teacherName,
          'teacherEmail': data['teacherEmail'] ?? _teacherEmail,
          'createdAt': (data['createdAt'] as Timestamp?)?.toDate(),
        };

        if (isExpired || meeting['status'] == 'expired' || meeting['status'] == 'disabled') {
          _expiredMeetings.add(meeting);
        } else if (meeting['status'] == 'active') {
          _activeMeetings.add(meeting);
        } else if (scheduledTime != null && now.isAfter(scheduledTime) && 
                   endTime != null && now.isBefore(endTime)) {
          _activeMeetings.add(meeting);
        } else {
          _upcomingMeetings.add(meeting);
        }
      }

      _upcomingMeetings.sort((a, b) {
        final aTime = a['scheduledTime'] as DateTime?;
        final bTime = b['scheduledTime'] as DateTime?;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return aTime.compareTo(bTime);
      });

      setState(() {});
    } catch (e) {
      print('Error fetching zoom meetings: $e');
    }
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';
    return DateFormat('MMM dd, yyyy • hh:mm a').format(dateTime);
  }

  String _formatDateTimeShort(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';
    return DateFormat('MMM dd, hh:mm a').format(dateTime);
  }

  String _getTimeRemaining(DateTime? dateTime) {
    if (dateTime == null) return '';
    final now = DateTime.now();
    final difference = dateTime.difference(now);
    
    if (difference.isNegative) return 'Started';
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ${difference.inHours % 24}h left';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ${difference.inMinutes % 60}m left';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m left';
    } else {
      return 'Soon';
    }
  }

  void _goToLogin() {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    }
  }

  Future<void> _logout(BuildContext context) async {
    await _auth.signOut();
    if (context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    }
  }

  // =============================================
  // CREATE MEETING DIALOG
  // =============================================
  Future<void> _showCreateMeetingDialog() async {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController zoomLinkController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    String selectedYear = _academicYears.isNotEmpty ? _academicYears[0] : '2024';
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedTime = TimeOfDay.now();
    int duration = 60;

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 10))],
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF4F46E5)]),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.video_call, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Create Zoom Class', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                              Text('Schedule a new online session', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, color: Color(0xFF9CA3AF), size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildInputField(titleController, 'Meeting Title', Icons.title),
                    const SizedBox(height: 10),
                    _buildInputField(zoomLinkController, 'Zoom Meeting Link', Icons.link),
                    const SizedBox(height: 10),
                    _buildInputField(descriptionController, 'Description (Optional)', Icons.description, maxLines: 2),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE5E7EB))),
                      child: DropdownButtonFormField<String>(
                        value: _academicYears.contains(selectedYear) ? selectedYear : (_academicYears.isNotEmpty ? _academicYears[0] : null),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          prefixIcon: Icon(Icons.school, color: Color(0xFF8B5CF6), size: 20),
                        ),
                        style: const TextStyle(fontSize: 14, color: Color(0xFF111827)),
                        items: _academicYears.isEmpty 
                            ? [const DropdownMenuItem(value: '2024', child: Text('No students enrolled'))]
                            : _academicYears.map((year) {
                                final count = _enrolledStudentsByYear[year]?.length ?? 0;
                                return DropdownMenuItem(value: year, child: Text('AL $year  •  $count students'));
                              }).toList(),
                        onChanged: (value) { if (value != null) setDialogState(() => selectedYear = value); },
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(flex: 2, child: _buildDatePicker(setDialogState, selectedDate, (d) => selectedDate = d)),
                        const SizedBox(width: 8),
                        Expanded(flex: 2, child: _buildTimePicker(context, setDialogState, selectedTime, (t) => selectedTime = t)),
                        const SizedBox(width: 8),
                        Expanded(flex: 1, child: _buildDurationDropdown(duration, (d) => duration = d, setDialogState)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.group, color: Color(0xFF10B981), size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                              Text('AL $selectedYear', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
                              Text('${_enrolledStudentsByYear[selectedYear]?.length ?? 0} enrolled students', style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                            ]),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(12)),
                            child: Text('${_enrolledStudentsByYear[selectedYear]?.length ?? 0}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: TextButton(onPressed: () => Navigator.pop(context), style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), foregroundColor: const Color(0xFF6B7280)), child: const Text('Cancel', style: TextStyle(fontSize: 14)))),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () async {
                              if (titleController.text.isEmpty || zoomLinkController.text.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all required fields'), backgroundColor: Colors.red));
                                return;
                              }
                              final studentIds = _enrolledStudentsByYear[selectedYear]?.keys.toList() ?? [];
                              if (studentIds.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No students for AL $selectedYear'), backgroundColor: Colors.orange));
                                return;
                              }
                              final scheduledDateTime = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, selectedTime.hour, selectedTime.minute);
                              final expiryTime = scheduledDateTime.add(Duration(minutes: duration + 30));
                              try {
                                await _firestore.collection('zoomMeetings').add({
                                  'teacherId': _auth.currentUser?.uid,
                                  'title': titleController.text,
                                  'zoomLink': zoomLinkController.text,
                                  'description': descriptionController.text,
                                  'academicYear': selectedYear,
                                  'scheduledTime': Timestamp.fromDate(scheduledDateTime),
                                  'expiryTime': Timestamp.fromDate(expiryTime),
                                  'duration': duration,
                                  'students': studentIds,
                                  'joinedStudents': [],
                                  'joinedTimes': {},
                                  'status': 'approved',
                                  'createdAt': FieldValue.serverTimestamp(),
                                  'teacherName': _teacherName,
                                  'teacherEmail': _teacherEmail,
                                });
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Meeting created successfully!'), backgroundColor: Color(0xFF10B981)));
                                await _fetchZoomMeetings();
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                              }
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0),
                            child: const Text('Create Meeting', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField(TextEditingController controller, String hint, IconData icon, {int maxLines = 1}) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: TextField(
        controller: controller,
        style: const TextStyle(fontSize: 14),
        maxLines: maxLines,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          prefixIcon: Icon(icon, color: const Color(0xFF6366F1), size: 20),
        ),
      ),
    );
  }

  Widget _buildDatePicker(void Function(void Function()) setState, DateTime date, void Function(DateTime) onChanged) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(context: context, initialDate: date, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
        if (picked != null) { setState(() => onChanged(picked)); }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE5E7EB))),
        child: Row(children: [const Icon(Icons.calendar_today, color: Color(0xFF3B82F6), size: 18), const SizedBox(width: 8), Flexible(child: Text('${date.day}/${date.month}/${date.year}', style: const TextStyle(fontSize: 13, color: Color(0xFF111827)), overflow: TextOverflow.ellipsis))]),
      ),
    );
  }

  Widget _buildTimePicker(BuildContext ctx, void Function(void Function()) setState, TimeOfDay time, void Function(TimeOfDay) onChanged) {
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(context: ctx, initialTime: time);
        if (picked != null) { setState(() => onChanged(picked)); }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE5E7EB))),
        child: Row(children: [const Icon(Icons.access_time, color: Color(0xFF3B82F6), size: 18), const SizedBox(width: 8), Flexible(child: Text(time.format(ctx), style: const TextStyle(fontSize: 13, color: Color(0xFF111827)), overflow: TextOverflow.ellipsis))]),
      ),
    );
  }

  Widget _buildDurationDropdown(int duration, void Function(int) onChanged, void Function(void Function()) setState) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: DropdownButtonFormField<int>(
        value: duration,
        decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
        style: const TextStyle(fontSize: 12, color: Color(0xFF111827)),
        items: [30, 45, 60, 90, 120].map((v) => DropdownMenuItem(value: v, child: Text('$v min', style: const TextStyle(fontSize: 11)))).toList(),
        onChanged: (v) { if (v != null) setState(() => onChanged(v)); },
      ),
    );
  }

  // =============================================
  // MEETING ACTIONS
  // =============================================
  Future<void> _startMeeting(String meetingId) async {
    try {
      await _firestore.collection('zoomMeetings').doc(meetingId).update({'status': 'active', 'startedAt': FieldValue.serverTimestamp()});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Meeting started!'), backgroundColor: Color(0xFF10B981)));
      await _fetchZoomMeetings();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _disableMeeting(String meetingId) async {
    try {
      await _firestore.collection('zoomMeetings').doc(meetingId).update({'status': 'disabled'});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Meeting disabled'), backgroundColor: Color(0xFFF59E0B)));
      await _fetchZoomMeetings();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _deleteMeeting(String meetingId) async {
    try {
      await _firestore.collection('zoomMeetings').doc(meetingId).delete();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Meeting deleted'), backgroundColor: Color(0xFF10B981)));
      await _fetchZoomMeetings();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _simulateStudentJoin(String meetingId) async {
    try {
      final studentIds = _enrolledStudentsByYear.values
          .expand((map) => map.keys)
          .toList();
      
      if (studentIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No students available'), backgroundColor: Colors.orange));
        return;
      }
      
      studentIds.shuffle();
      final randomStudent = studentIds.first;
      
      await _firestore.collection('zoomMeetings').doc(meetingId).update({
        'joinedStudents': FieldValue.arrayUnion([randomStudent]),
        'joinedTimes.$randomStudent': FieldValue.serverTimestamp(),
      });
      
      final studentName = _studentDetails[randomStudent]?['name'] ?? 'Unknown';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$studentName joined the meeting'), backgroundColor: Color(0xFF10B981)));
      await _fetchZoomMeetings();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  // =============================================
  // COMPACT MODERN MEETING CARD
  // =============================================
  Widget _buildModernMeetingCard(Map<String, dynamic> meeting) {
    final scheduledTime = meeting['scheduledTime'] as DateTime?;
    final expiryTime = meeting['expiryTime'] as DateTime?;
    final status = meeting['status'] ?? 'upcoming';
    final studentList = List<String>.from(meeting['students'] ?? []);
    final joinedList = List<String>.from(meeting['joinedStudents'] ?? []);
    
    final isUpcoming = status == 'approved' || status == 'upcoming';
    final isActive = status == 'active';
    final isExpired = status == 'expired';
    final isDisabled = status == 'disabled';
    
    Color accentColor;
    Color bgColor;
    String statusText;
    IconData statusIcon;
    
    if (isActive) {
      accentColor = const Color(0xFF10B981);
      bgColor = const Color(0xFFECFDF5);
      statusText = 'LIVE';
      statusIcon = Icons.fiber_manual_record;
    } else if (isUpcoming) {
      accentColor = const Color(0xFF6366F1);
      bgColor = const Color(0xFFEEF2FF);
      statusText = 'UPCOMING';
      statusIcon = Icons.schedule;
    } else if (isDisabled) {
      accentColor = const Color(0xFFF59E0B);
      bgColor = const Color(0xFFFFFBEB);
      statusText = 'DISABLED';
      statusIcon = Icons.block;
    } else {
      accentColor = const Color(0xFF9CA3AF);
      bgColor = const Color(0xFFF9FAFB);
      statusText = 'EXPIRED';
      statusIcon = Icons.history;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? accentColor.withOpacity(0.3) : const Color(0xFFE5E7EB),
          width: isActive ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                color: bgColor,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: isActive ? 10 : 12, color: accentColor),
                          const SizedBox(width: 4),
                          Text(statusText, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: accentColor, letterSpacing: 0.5)),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (isUpcoming && scheduledTime != null)
                      Text(_getTimeRemaining(scheduledTime), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: accentColor)),
                    if (isActive)
                      Container(width: 6, height: 6, decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle, boxShadow: [BoxShadow(color: accentColor.withOpacity(0.4), blurRadius: 4)])),
                  ],
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            meeting['title'] ?? 'Zoom Meeting',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF111827), height: 1.2),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(6)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.access_time, size: 12, color: Color(0xFF6B7280)),
                              const SizedBox(width: 3),
                              Text('${meeting['duration'] ?? 60}m', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    if (meeting['description'] != null && meeting['description'].toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(meeting['description'], style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), height: 1.3), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    
                    const SizedBox(height: 10),
                    
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _buildInfoChip(Icons.school, 'AL ${meeting['academicYear'] ?? '2024'}', const Color(0xFF8B5CF6)),
                        _buildInfoChip(Icons.people, '${studentList.length} Students', const Color(0xFFF59E0B)),
                        _buildInfoChip(Icons.calendar_today, _formatDateTimeShort(scheduledTime), const Color(0xFF3B82F6)),
                        if (expiryTime != null)
                          _buildInfoChip(Icons.timer_off, 'Exp: ${_formatDateTimeShort(expiryTime)}', const Color(0xFFEF4444)),
                      ],
                    ),
                    
                    if ((isActive || isExpired) && studentList.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.check_circle, size: 12, color: Color(0xFF10B981)),
                                const SizedBox(width: 4),
                                Text('Joined ${joinedList.length}/${studentList.length}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF6B7280))),
                                const Spacer(),
                                if (joinedList.isNotEmpty)
                                  GestureDetector(
                                    onTap: () => _showJoinedStudentsList(meeting),
                                    child: const Text('View', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF6366F1))),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: joinedList.length / studentList.length,
                                backgroundColor: const Color(0xFFE5E7EB),
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                                minHeight: 3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    const SizedBox(height: 12),
                    
                    Row(
                      children: [
                        if (isUpcoming) ...[
                          Expanded(child: _buildActionButton(label: 'Start', icon: Icons.play_arrow, bgColor: const Color(0xFF10B981), onTap: () => _showStartConfirmation(meeting))),
                          const SizedBox(width: 6),
                          _buildIconActionButton(icon: Icons.block, color: const Color(0xFFF59E0B), onTap: () => _showDisableConfirmation(meeting['id']), tooltip: 'Disable'),
                        ],
                        if (isActive) ...[
                          Expanded(child: _buildActionButton(label: 'Join Now', icon: Icons.video_call, bgColor: const Color(0xFF10B981), onTap: () => _launchZoomMeeting(meeting['zoomLink'] ?? ''))),
                          const SizedBox(width: 6),
                          _buildIconActionButton(icon: Icons.person_add, color: const Color(0xFF6366F1), onTap: () => _simulateStudentJoin(meeting['id']), tooltip: 'Simulate Join'),
                          const SizedBox(width: 6),
                          _buildIconActionButton(icon: Icons.stop_circle, color: const Color(0xFFEF4444), onTap: () => _showDisableConfirmation(meeting['id']), tooltip: 'End'),
                        ],
                        if (isExpired || isDisabled) ...[
                          Expanded(child: _buildActionButton(label: 'View Details', icon: Icons.info_outline, bgColor: const Color(0xFF6B7280), onTap: () => _showMeetingDetails(meeting))),
                        ],
                        const SizedBox(width: 6),
                        _buildIconActionButton(icon: Icons.delete_outline, color: const Color(0xFFEF4444), onTap: () => _showDeleteConfirmation(meeting['id']), tooltip: 'Delete'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =============================================
  // MODERN JOINED STUDENTS LIST MODAL
  // =============================================
  void _showJoinedStudentsList(Map<String, dynamic> meeting) {
    final joinedList = List<String>.from(meeting['joinedStudents'] ?? []);
    final joinedTimes = Map<String, dynamic>.from(meeting['joinedTimes'] ?? {});
    final totalStudents = List<String>.from(meeting['students'] ?? []).length;
    final attendancePercent = totalStudents > 0 ? (joinedList.length / totalStudents * 100).toStringAsFixed(0) : '0';
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF10B981), Color(0xFF059669)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF10B981).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              meeting['title'] ?? 'Meeting',
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'AL ${meeting['academicYear'] ?? 'N/A'}',
                              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.close, size: 18, color: Color(0xFF6B7280)),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Attendance Summary Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF10B981).withOpacity(0.08),
                          const Color(0xFF059669).withOpacity(0.03),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF10B981).withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        // Circular progress
                        SizedBox(
                          width: 60,
                          height: 60,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CircularProgressIndicator(
                                value: totalStudents > 0 ? joinedList.length / totalStudents : 0,
                                backgroundColor: const Color(0xFFE5E7EB),
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                                strokeWidth: 5,
                              ),
                              Center(
                                child: Text(
                                  '$attendancePercent%',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF10B981),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Attendance',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  _buildAttendanceStat(joinedList.length, 'Joined', const Color(0xFF10B981)),
                                  Container(
                                    width: 1,
                                    height: 24,
                                    color: const Color(0xFFD1D5DB),
                                    margin: const EdgeInsets.symmetric(horizontal: 12),
                                  ),
                                  _buildAttendanceStat(totalStudents - joinedList.length, 'Absent', const Color(0xFFEF4444)),
                                  Container(
                                    width: 1,
                                    height: 24,
                                    color: const Color(0xFFD1D5DB),
                                    margin: const EdgeInsets.symmetric(horizontal: 12),
                                  ),
                                  _buildAttendanceStat(totalStudents, 'Total', const Color(0xFF6366F1)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Divider
            Container(
              height: 1,
              color: const Color(0xFFF3F4F6),
              margin: const EdgeInsets.symmetric(horizontal: 20),
            ),
            
            // Student List Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 16,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Joined Students (${joinedList.length})',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
                  ),
                  const Spacer(),
                  Icon(Icons.access_time, size: 14, color: Colors.grey.shade400),
                  const SizedBox(width: 4),
                  Text(
                    'Join Time',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            
            // Student List
            Expanded(
              child: joinedList.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.person_off_outlined, size: 40, color: Colors.grey.shade400),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No students joined yet',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Students will appear here once they join',
                            style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: joinedList.length,
                      itemBuilder: (ctx, index) {
                        final studentId = joinedList[index];
                        final student = _studentDetails[studentId];
                        final joinTimestamp = joinedTimes[studentId];
                        DateTime? joinTime;
                        if (joinTimestamp is Timestamp) {
                          joinTime = joinTimestamp.toDate();
                        }
                        
                        final initials = (student?['name'] ?? '?')
                            .split(' ')
                            .take(2)
                            .map((e) => e.isNotEmpty ? e[0].toUpperCase() : '')
                            .join();
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFF3F4F6)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  // Avatar
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          const Color(0xFF10B981).withOpacity(0.2),
                                          const Color(0xFF059669).withOpacity(0.1),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: Text(
                                        initials,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF059669),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  
                                  // Student Info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          student?['name'] ?? 'Unknown Student',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF111827),
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Row(
                                          children: [
                                            if (student?['studentId'] != null) ...[
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF6366F1).withOpacity(0.08),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  student!['studentId'],
                                                  style: const TextStyle(fontSize: 10, color: Color(0xFF6366F1), fontWeight: FontWeight.w500),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                            ],
                                            if (student?['email'] != null)
                                              Expanded(
                                                child: Text(
                                                  student!['email'],
                                                  style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  // Join Time
                                  if (joinTime != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981).withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.login_rounded, size: 12, color: Color(0xFF10B981)),
                                          const SizedBox(width: 4),
                                          Text(
                                            DateFormat('hh:mm a').format(joinTime),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF10B981),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceStat(int count, String label, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          count.toString(),
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        ),
      ],
    );
  }

  Widget _buildInfoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  Widget _buildActionButton({required String label, required IconData icon, required Color bgColor, required VoidCallback onTap}) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      style: ElevatedButton.styleFrom(
        backgroundColor: bgColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
      ),
    );
  }

  Widget _buildIconActionButton({required IconData icon, required Color color, required VoidCallback onTap, String? tooltip}) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, size: 18, color: color),
          ),
        ),
      ),
    );
  }

  // =============================================
  // CONFIRMATION DIALOGS
  // =============================================
  void _showStartConfirmation(Map<String, dynamic> meeting) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Start Meeting'),
        content: Text('Start "${meeting['title']}" now?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); _startMeeting(meeting['id']); },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Start Now'),
          ),
        ],
      ),
    );
  }

  void _showDisableConfirmation(String meetingId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Disable Meeting'),
        content: const Text('Students will not be able to join. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); _disableMeeting(meetingId); },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Disable'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(String meetingId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Meeting'),
        content: const Text('This action cannot be undone. Delete?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); _deleteMeeting(meetingId); },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showMeetingDetails(Map<String, dynamic> meeting) {
    final scheduledTime = meeting['scheduledTime'] as DateTime?;
    final expiryTime = meeting['expiryTime'] as DateTime?;
    final studentList = List<String>.from(meeting['students'] ?? []);
    final joinedList = List<String>.from(meeting['joinedStudents'] ?? []);
    final joinedTimes = Map<String, dynamic>.from(meeting['joinedTimes'] ?? {});
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (ctx, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.video_call, color: Color(0xFF6366F1), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(meeting['title'] ?? 'Meeting Details', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                        Text('AL ${meeting['academicYear'] ?? 'N/A'}', style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close, color: Color(0xFF9CA3AF)),
                  ),
                ],
              ),
              const Divider(height: 24),
              
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        children: [
                          _detailTile(Icons.calendar_today, 'Scheduled', _formatDateTime(scheduledTime), const Color(0xFF3B82F6)),
                          const Divider(height: 16),
                          _detailTile(Icons.timer, 'Duration', '${meeting['duration'] ?? 60} minutes', const Color(0xFFF59E0B)),
                          const Divider(height: 16),
                          _detailTile(Icons.timer_off, 'Expires', _formatDateTime(expiryTime), const Color(0xFFEF4444)),
                          const Divider(height: 16),
                          _detailTile(Icons.info, 'Status', meeting['status'] ?? 'N/A', const Color(0xFF10B981)),
                          if (meeting['description'] != null && meeting['description'].toString().isNotEmpty) ...[
                            const Divider(height: 16),
                            _detailTile(Icons.description, 'Description', meeting['description'], const Color(0xFF8B5CF6)),
                          ],
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.people, color: Color(0xFF10B981), size: 20),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Student Attendance', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
                              Text('${joinedList.length} of ${studentList.length} joined', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                            ],
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${studentList.isEmpty ? 0 : (joinedList.length / studentList.length * 100).toStringAsFixed(0)}%',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    Row(
                      children: [
                        const Icon(Icons.check_circle, size: 18, color: Color(0xFF10B981)),
                        const SizedBox(width: 8),
                        Text('Joined Students (${joinedList.length})', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
                      ],
                    ),
                    
                    if (joinedList.isEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: const Center(
                          child: Text('No students have joined yet', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
                        ),
                      )
                    else
                      ...joinedList.map((studentId) {
                        final student = _studentDetails[studentId];
                        final joinTimestamp = joinedTimes[studentId];
                        DateTime? joinTime;
                        if (joinTimestamp is Timestamp) {
                          joinTime = joinTimestamp.toDate();
                        }
                        
                        return Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: const Color(0xFF10B981).withOpacity(0.1),
                                child: Text(
                                  (student?['name'] ?? '?')[0].toUpperCase(),
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981), fontSize: 12),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      student?['name'] ?? 'Unknown Student',
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
                                    ),
                                    if (student?['studentId'] != null)
                                      Text(
                                        student!['studentId'],
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                                      ),
                                  ],
                                ),
                              ),
                              if (joinTime != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    DateFormat('hh:mm a').format(joinTime),
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF10B981)),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }),
                    
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailTile(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 10),
        Text('$label:', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF6B7280))),
        const SizedBox(width: 6),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF111827)), textAlign: TextAlign.end),
        ),
      ],
    );
  }

  void _launchZoomMeeting(String link) {
    if (link.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No Zoom link available'), backgroundColor: Colors.orange));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening: $link'),
        backgroundColor: const Color(0xFF6366F1),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(label: 'Copy', onPressed: () {}, textColor: Colors.white),
      ),
    );
  }


  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.only(top: 10, left: 20, right: 20, bottom: 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.buttonGradientStart, AppColors.buttonGradientEnd], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Color(0x10000000), blurRadius: 15, offset: Offset(0, 5))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          IconButton(icon: const Icon(Icons.menu, color: Colors.white, size: 28), onPressed: () => _scaffoldKey.currentState?.openDrawer(), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
          const Spacer(),
          Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_teacherName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 4),
            const Text('Logged in as: Teacher', style: TextStyle(fontSize: 12, color: Colors.white70)),
          ]),
          const Spacer(),
          CircleAvatar(radius: 40, backgroundImage: NetworkImage(_profileImageUrl), backgroundColor: Colors.grey.shade200, onBackgroundImageError: (_, __) {}, child: _profileImageUrl == _defaultProfileImageUrl ? const Icon(Icons.person, size: 40, color: Colors.white) : null),
        ]),
        const SizedBox(height: 20),
        const Text('Zoom Class Dashboard', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
      ]),
    );
  }

  Widget _buildDrawer() {
    return TeacherDrawer(userName: _teacherName, userEmail: _teacherEmail, profileImageUrl: _profileImageUrl, onLogout: () => _logout(context));
  }

  // =============================================
  // MAIN BUILD
  // =============================================
  @override
  Widget build(BuildContext context) {
    final totalMeetings = _activeMeetings.length + _upcomingMeetings.length + _expiredMeetings.length;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF9FAFB),
      drawer: _buildDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateMeetingDialog,
        icon: const Icon(Icons.add, size: 22),
        label: const Text('New Class'),
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
          : Column(children: [
              _buildHeader(),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _fetchZoomMeetings,
                  color: const Color(0xFF6366F1),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        _buildSummaryCard('Total', totalMeetings, const Color(0xFF6366F1), Icons.video_call),
                        const SizedBox(width: 10),
                        _buildSummaryCard('Live', _activeMeetings.length, const Color(0xFF10B981), Icons.live_tv),
                        const SizedBox(width: 10),
                        _buildSummaryCard('Upcoming', _upcomingMeetings.length, const Color(0xFF8B5CF6), Icons.schedule),
                        const SizedBox(width: 10),
                        _buildSummaryCard('Expired', _expiredMeetings.length, const Color(0xFF9CA3AF), Icons.history),
                      ]),
                      const SizedBox(height: 20),
                      
                      if (_activeMeetings.isNotEmpty) ...[
                        _buildSectionHeader('Live Now', const Color(0xFF10B981), _activeMeetings.length),
                        const SizedBox(height: 10),
                        ..._activeMeetings.map((m) => _buildModernMeetingCard(m)),
                      ],
                      
                      if (_upcomingMeetings.isNotEmpty) ...[
                        _buildSectionHeader('Upcoming Classes', const Color(0xFF6366F1), _upcomingMeetings.length),
                        const SizedBox(height: 10),
                        ..._upcomingMeetings.map((m) => _buildModernMeetingCard(m)),
                      ],
                      
                      if (_expiredMeetings.isNotEmpty) ...[
                        _buildSectionHeader('Expired/Disabled', const Color(0xFF9CA3AF), _expiredMeetings.length),
                        const SizedBox(height: 10),
                        ..._expiredMeetings.map((m) => _buildModernMeetingCard(m)),
                      ],
                      
                      if (totalMeetings == 0)
                        Container(
                          padding: const EdgeInsets.all(40),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5E7EB))),
                          child: Column(children: [
                            Icon(Icons.video_call_outlined, size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            const Text('No Zoom Classes Scheduled', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF374151))),
                            const SizedBox(height: 8),
                            const Text('Tap + to create your first Zoom class', style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF))),
                          ]),
                        ),
                      
                      // Extra padding for FAB
                      const SizedBox(height: 80),
                    ]),
                  ),
                ),
              ),
              // FIXED BOTTOM FOOTER - Non-scrollable
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  border: Border(
                    top: BorderSide(
                      color: Colors.grey.shade200,
                      width: 0.5,
                    ),
                  ),
                ),
                child: const Center(
                  child: Text(
                    'Developed By Devlk',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black45,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ]),
    );
  }

  Widget _buildSectionHeader(String title, Color color, int count) {
    return Row(children: [
      Container(width: 4, height: 20, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
      const SizedBox(width: 10),
      Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
      const Spacer(),
      Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Text('$count', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color))),
    ]);
  }

  Widget _buildSummaryCard(String label, int count, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE5E7EB)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))]),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 14, color: color), const SizedBox(width: 5), Text(count.toString(), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color))]),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
        ]),
      ),
    );
  }
}