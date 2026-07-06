import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/app_colors.dart';
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
  
  // Zoom Meetings
  List<Map<String, dynamic>> _upcomingMeetings = [];
  List<Map<String, dynamic>> _activeMeetings = [];
  List<Map<String, dynamic>> _expiredMeetings = [];
  
  // Students by academic year for meeting creation
  Map<String, List<String>> _studentsByYear = {};
  Map<String, List<Map<String, dynamic>>> _studentsDetailsByYear = {};
  List<String> _academicYears = [];

  static const String _defaultProfileImageUrl =
      'https://res.cloudinary.com/dqeptzlsb/image/upload/v1782734371/default_il19eg.png';

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
        _fetchStudents(),
        _fetchZoomMeetings(),
      ]);
    } catch (e) {
      print('Error loading teacher data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchStudents() async {
    try {
      final usersSnapshot = await _firestore.collection('users').get();
      final students = usersSnapshot.docs
          .where((doc) => doc.data()['role'] == 'user')
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {
              'id': doc.id,
              'name': data['name'] ?? 'Unknown',
              'stream': data['stream'] ?? '',
              'subjects': List<String>.from(data['subjects'] ?? []),
              'academicYear': data['academicYear'] ?? '2024',
              'studentId': data['studentId'] ?? '',
              'email': data['email'] ?? '',
              'profileImageUrl': data['profileImageUrl'] ?? _defaultProfileImageUrl,
            };
          })
          .toList();

      // Filter students by teacher's stream and subjects
      final filteredStudents = students.where((student) {
        final studentSubjects = List<String>.from(student['subjects']);
        bool hasMatchingSubject = false;
        for (var subject in studentSubjects) {
          if (_teacherSubjects.contains(subject)) {
            hasMatchingSubject = true;
            break;
          }
        }
        final studentStream = student['stream'] ?? '';
        bool hasMatchingStream = _teacherStream.isNotEmpty && 
                                 studentStream == _teacherStream;
        return hasMatchingSubject || hasMatchingStream;
      }).toList();

      // Group by academic year
      _studentsByYear = {};
      _studentsDetailsByYear = {};
      for (var student in filteredStudents) {
        final year = student['academicYear'] ?? '2024';
        if (!_studentsByYear.containsKey(year)) {
          _studentsByYear[year] = [];
          _studentsDetailsByYear[year] = [];
        }
        _studentsByYear[year]!.add(student['id']);
        _studentsDetailsByYear[year]!.add(student);
      }

      _academicYears = _studentsByYear.keys.toList()..sort((a, b) => b.compareTo(a));
    } catch (e) {
      print('Error fetching students: $e');
    }
  }

  Future<void> _fetchZoomMeetings() async {
    try {
      final teacherId = _auth.currentUser?.uid;
      if (teacherId == null) return;

      final meetingsSnapshot = await _firestore
          .collection('zoomMeetings')
          .where('teacherId', isEqualTo: teacherId)
          .orderBy('scheduledTime', descending: false)
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
        final endTime = scheduledTime?.add(Duration(minutes: duration));
        
        // Get student details for this meeting
        final studentIds = List<String>.from(data['students'] ?? []);
        final studentDetails = <Map<String, dynamic>>[];
        for (var studentId in studentIds) {
          try {
            final studentDoc = await _firestore.collection('users').doc(studentId).get();
            if (studentDoc.exists) {
              final studentData = studentDoc.data() as Map<String, dynamic>;
              studentDetails.add({
                'id': studentId,
                'name': studentData['name'] ?? 'Unknown',
                'studentId': studentData['studentId'] ?? '',
                'email': studentData['email'] ?? '',
                'profileImageUrl': studentData['profileImageUrl'] ?? _defaultProfileImageUrl,
              });
            }
          } catch (e) {
            print('Error fetching student: $e');
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
          'batchNumber': data['batchNumber'] ?? 1,
          'totalBatches': data['totalBatches'] ?? 1,
          'students': studentIds,
          'studentDetails': studentDetails,
          'status': data['status'] ?? 'upcoming',
        };

        if (scheduledTime == null) {
          _upcomingMeetings.add(meeting);
        } else if (expiryTime != null && now.isAfter(expiryTime)) {
          _expiredMeetings.add(meeting);
        } else if (now.isAfter(scheduledTime) && 
                   endTime != null && 
                   now.isBefore(endTime)) {
          _activeMeetings.add(meeting);
        } else if (now.isBefore(scheduledTime)) {
          _upcomingMeetings.add(meeting);
        } else {
          _expiredMeetings.add(meeting);
        }
      }

      // Sort meetings
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

  // ---- Create Meeting Dialog ----
  Future<void> _showCreateMeetingDialog() async {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController zoomLinkController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    String selectedYear = _academicYears.isNotEmpty ? _academicYears[0] : '2024';
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedTime = TimeOfDay.now();
    int duration = 60;
    int totalBatches = 1;

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.video_call,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Create Zoom Class',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          Text(
                            'Schedule a new online session',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Form Fields
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      hintText: 'Meeting Title',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      prefixIcon: Icon(Icons.title, color: Color(0xFF2563EB)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: zoomLinkController,
                    decoration: const InputDecoration(
                      hintText: 'Zoom Meeting Link',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      prefixIcon: Icon(Icons.link, color: Color(0xFF2563EB)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      hintText: 'Description (Optional)',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      prefixIcon: Icon(Icons.description, color: Color(0xFF2563EB)),
                    ),
                    maxLines: 2,
                  ),
                ),
                const SizedBox(height: 12),
                
                // Academic Year Dropdown
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonFormField<String>(
                    value: selectedYear,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      prefixIcon: Icon(Icons.calendar_today, color: Color(0xFF2563EB), size: 20),
                    ),
                    items: _academicYears.map((year) {
                      return DropdownMenuItem(
                        value: year,
                        child: Row(
                          children: [
                            Icon(Icons.calendar_month, size: 16, color: Colors.grey.shade600),
                            const SizedBox(width: 8),
                            Text('Academic Year $year'),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${_studentsByYear[year]?.length ?? 0} students',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: const Color(0xFF2563EB),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => selectedYear = value);
                    },
                  ),
                ),
                const SizedBox(height: 12),
                
                // Batches
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonFormField<int>(
                    value: totalBatches,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      prefixIcon: Icon(Icons.groups, color: Color(0xFF2563EB), size: 20),
                    ),
                    items: [1, 2, 3, 4, 5].map((value) {
                      return DropdownMenuItem(
                        value: value,
                        child: Text('$value batches'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => totalBatches = value);
                    },
                  ),
                ),
                const SizedBox(height: 12),
                
                // Date & Time pickers
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (date != null) {
                            setState(() => selectedDate = date);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, color: Color(0xFF2563EB), size: 20),
                              const SizedBox(width: 10),
                              Text(
                                '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: selectedTime,
                          );
                          if (time != null) {
                            setState(() => selectedTime = time);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.access_time, color: Color(0xFF2563EB), size: 20),
                              const SizedBox(width: 10),
                              Text(
                                selectedTime.format(context),
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonFormField<int>(
                          value: duration,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            prefixIcon: Icon(Icons.timer, color: Color(0xFF2563EB), size: 20),
                          ),
                          items: [30, 45, 60, 90, 120].map((value) {
                            return DropdownMenuItem(
                              value: value,
                              child: Text('$value min'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) setState(() => duration = value);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Students count
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.school, color: const Color(0xFF2563EB), size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${_studentsByYear[selectedYear]?.length ?? 0} students from Year $selectedYear will be assigned',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                
                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          foregroundColor: Colors.grey.shade600,
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          if (titleController.text.isEmpty || zoomLinkController.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please fill all required fields'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          final scheduledDateTime = DateTime(
                            selectedDate.year,
                            selectedDate.month,
                            selectedDate.day,
                            selectedTime.hour,
                            selectedTime.minute,
                          );

                          final studentIds = _studentsByYear[selectedYear] ?? [];
                          final expiryTime = scheduledDateTime.add(
                            Duration(minutes: duration + 30)
                          );

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
                              'totalBatches': totalBatches,
                              'batchNumber': 1,
                              'students': studentIds,
                              'status': 'upcoming',
                              'createdAt': FieldValue.serverTimestamp(),
                              'teacherName': _teacherName,
                              'teacherEmail': _teacherEmail,
                            });

                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Zoom meeting created successfully!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                            await _fetchZoomMeetings();
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error creating meeting: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Create Meeting',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---- Build Meeting Card ----
  Widget _buildMeetingCard(Map<String, dynamic> meeting) {
    final scheduledTime = meeting['scheduledTime'] as DateTime?;
    final expiryTime = meeting['expiryTime'] as DateTime?;
    final now = DateTime.now();
    final isUpcoming = meeting['status'] == 'upcoming' && scheduledTime != null && now.isBefore(scheduledTime);
    final isActive = meeting['status'] == 'active' || (scheduledTime != null && now.isAfter(scheduledTime) && expiryTime != null && now.isBefore(expiryTime));
    final isExpired = meeting['status'] == 'expired' || (expiryTime != null && now.isAfter(expiryTime));

    Color statusColor;
    String statusText;
    IconData statusIcon;
    
    if (isActive) {
      statusColor = const Color(0xFF059669);
      statusText = '● Live Now';
      statusIcon = Icons.live_tv;
    } else if (isUpcoming) {
      statusColor = const Color(0xFF2563EB);
      statusText = '● Upcoming';
      statusIcon = Icons.schedule;
    } else {
      statusColor = Colors.grey.shade500;
      statusText = '● Expired';
      statusIcon = Icons.cancel;
    }

    final studentDetails = List<Map<String, dynamic>>.from(meeting['studentDetails'] ?? []);
    final academicYear = meeting['academicYear'] ?? '2024';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isActive ? const Color(0xFF059669).withOpacity(0.3) : Colors.grey.shade200,
          width: isActive ? 2 : 1,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: isActive 
              ? LinearGradient(
                  colors: [
                    const Color(0xFF059669).withOpacity(0.05),
                    Colors.white,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isActive ? Icons.video_call : Icons.video_call_outlined,
                      color: statusColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          meeting['title'] ?? 'Zoom Meeting',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        Row(
                          children: [
                            Icon(Icons.calendar_month, size: 14, color: Colors.grey.shade500),
                            const SizedBox(width: 4),
                            Text(
                              'Year $academicYear',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF2563EB),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF7C3AED).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${studentDetails.length} students',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: const Color(0xFF7C3AED),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 14, color: statusColor),
                        const SizedBox(width: 6),
                        Text(
                          statusText.replaceAll('● ', ''),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              
              // Description
              if (meeting['description'] != null && meeting['description'].toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    meeting['description'],
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              
              // Time and Duration
              Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Text(
                    scheduledTime != null 
                        ? '${scheduledTime.day}/${scheduledTime.month}/${scheduledTime.year} ${scheduledTime.hour.toString().padLeft(2, '0')}:${scheduledTime.minute.toString().padLeft(2, '0')}'
                        : 'Not scheduled',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.timer, size: 16, color: Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Text(
                    '${meeting['duration'] ?? 60} min',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Students List - Academic Year Students
              if (studentDetails.isNotEmpty) ...[
                const Text(
                  'Students from this Academic Year:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: studentDetails.take(5).map((student) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 10,
                              backgroundImage: NetworkImage(student['profileImageUrl'] ?? _defaultProfileImageUrl),
                              backgroundColor: Colors.grey.shade200,
                              child: student['profileImageUrl'] == _defaultProfileImageUrl
                                  ? const Icon(Icons.person, size: 10, color: Colors.white)
                                  : null,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              student['name'] ?? 'Unknown',
                              style: TextStyle(
                                fontSize: 11,
                                color: const Color(0xFF1E293B),
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            if (student['studentId'] != null && student['studentId'].toString().isNotEmpty) ...[
                              const SizedBox(width: 2),
                              Text(
                                '(${student['studentId']})',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                if (studentDetails.length > 5)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '+ ${studentDetails.length - 5} more students',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
              ],
              
              // Action Buttons
              Row(
                children: [
                  if (isActive)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final link = meeting['zoomLink'] ?? '';
                          if (link.isNotEmpty) {
                            _launchZoomMeeting(link);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Zoom link not available'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.video_call, size: 18),
                        label: const Text('Join Now'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  if (isUpcoming)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          _showMeetingDetails(meeting);
                        },
                        icon: const Icon(Icons.info_outline, size: 18),
                        label: const Text('View Details'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF2563EB),
                          side: const BorderSide(color: Color(0xFF2563EB)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  if (isExpired)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          _showMeetingDetails(meeting);
                        },
                        icon: const Icon(Icons.history, size: 18),
                        label: const Text('View'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey.shade500,
                          side: BorderSide(color: Colors.grey.shade300),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(width: 10),
                  PopupMenuButton(
                    icon: Icon(Icons.more_vert, color: Colors.grey.shade500),
                    onSelected: (value) {
                      if (value == 'delete') {
                        _showDeleteConfirmation(meeting['id']);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red, size: 18),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(String meetingId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Meeting'),
        content: const Text('Are you sure you want to delete this meeting?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteMeeting(meetingId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteMeeting(String meetingId) async {
    try {
      await _firestore.collection('zoomMeetings').doc(meetingId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Meeting deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
      await _fetchZoomMeetings();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting meeting: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showMeetingDetails(Map<String, dynamic> meeting) {
    final scheduledTime = meeting['scheduledTime'] as DateTime?;
    final isActive = meeting['status'] == 'active' || 
                     (scheduledTime != null && 
                      DateTime.now().isAfter(scheduledTime) &&
                      meeting['expiryTime'] != null &&
                      DateTime.now().isBefore(meeting['expiryTime']));
    
    final studentDetails = List<Map<String, dynamic>>.from(meeting['studentDetails'] ?? []);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(meeting['title'] ?? 'Meeting Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (meeting['description'] != null && meeting['description'].toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    meeting['description'],
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              _buildDetailRow(Icons.calendar_month, 'Academic Year', meeting['academicYear'] ?? '2024'),
              _buildDetailRow(Icons.access_time, 'Scheduled', 
                  scheduledTime != null 
                      ? '${scheduledTime.day}/${scheduledTime.month}/${scheduledTime.year} ${scheduledTime.hour.toString().padLeft(2, '0')}:${scheduledTime.minute.toString().padLeft(2, '0')}'
                      : 'Not scheduled'),
              _buildDetailRow(Icons.timer, 'Duration', '${meeting['duration'] ?? 60} minutes'),
              _buildDetailRow(Icons.groups, 'Batches', '${meeting['totalBatches'] ?? 1}'),
              _buildDetailRow(Icons.school, 'Total Students', '${studentDetails.length}'),
              if (meeting['zoomLink'] != null && meeting['zoomLink'].toString().isNotEmpty)
                _buildDetailRow(Icons.link, 'Zoom Link', meeting['zoomLink']),
              
              if (studentDetails.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  'Assigned Students:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: studentDetails.length,
                    separatorBuilder: (_, __) => const Divider(height: 4),
                    itemBuilder: (context, index) {
                      final student = studentDetails[index];
                      return Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundImage: NetworkImage(student['profileImageUrl'] ?? _defaultProfileImageUrl),
                            backgroundColor: Colors.grey.shade200,
                            child: student['profileImageUrl'] == _defaultProfileImageUrl
                                ? const Icon(Icons.person, size: 14, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              student['name'] ?? 'Unknown',
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (student['studentId'] != null && student['studentId'].toString().isNotEmpty)
                            Text(
                              student['studentId'],
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (isActive)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                final link = meeting['zoomLink'] ?? '';
                if (link.isNotEmpty) {
                  _launchZoomMeeting(link);
                }
              },
              icon: const Icon(Icons.video_call),
              label: const Text('Join Now'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 10),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _launchZoomMeeting(String link) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening Zoom: $link'),
        backgroundColor: const Color(0xFF2563EB),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Copy Link',
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Link copied to clipboard'),
                backgroundColor: Colors.green,
              ),
            );
          },
          textColor: Colors.white,
        ),
      ),
    );
  }

  // ---- Header ----
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.only(top: 10, left: 20, right: 20, bottom: 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.buttonGradientStart, AppColors.buttonGradientEnd],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.menu, color: Colors.white, size: 28),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const Spacer(),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _teacherName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Logged in as: Teacher',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              CircleAvatar(
                radius: 40,
                backgroundImage: NetworkImage(_profileImageUrl),
                backgroundColor: Colors.grey.shade200,
                onBackgroundImageError: (_, __) {},
                child: _profileImageUrl == _defaultProfileImageUrl
                    ? const Icon(Icons.person, size: 40, color: Colors.white)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Zoom Class Dashboard',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ---- Drawer ----
  Widget _buildDrawer() {
    return TeacherDrawer(
      userName: _teacherName,
      userEmail: _teacherEmail,
      profileImageUrl: _profileImageUrl,
      onLogout: () => _logout(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalMeetings = _activeMeetings.length + _upcomingMeetings.length + _expiredMeetings.length;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: _buildDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateMeetingDialog,
        icon: const Icon(Icons.add, size: 22),
        label: const Text('New Class'),
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
          : Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _fetchZoomMeetings,
                    color: const Color(0xFF2563EB),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Summary Cards
                          Row(
                            children: [
                              _buildSummaryCard(
                                label: 'Total',
                                count: totalMeetings,
                                color: const Color(0xFF2563EB),
                                icon: Icons.video_call,
                              ),
                              const SizedBox(width: 12),
                              _buildSummaryCard(
                                label: 'Live',
                                count: _activeMeetings.length,
                                color: const Color(0xFF059669),
                                icon: Icons.live_tv,
                              ),
                              const SizedBox(width: 12),
                              _buildSummaryCard(
                                label: 'Upcoming',
                                count: _upcomingMeetings.length,
                                color: const Color(0xFF7C3AED),
                                icon: Icons.schedule,
                              ),
                              const SizedBox(width: 12),
                              _buildSummaryCard(
                                label: 'Expired',
                                count: _expiredMeetings.length,
                                color: Colors.grey,
                                icon: Icons.cancel,
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          
                          // Active Meetings
                          if (_activeMeetings.isNotEmpty) ...[
                            Row(
                              children: [
                                Container(
                                  width: 4,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF059669),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  'Live Now',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF059669).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${_activeMeetings.length}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF059669),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ..._activeMeetings.map((meeting) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _buildMeetingCard(meeting),
                              );
                            }),
                            const SizedBox(height: 16),
                          ],
                          
                          // Upcoming Meetings
                          if (_upcomingMeetings.isNotEmpty) ...[
                            Row(
                              children: [
                                Container(
                                  width: 4,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2563EB),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  'Upcoming Classes',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2563EB).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${_upcomingMeetings.length}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF2563EB),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ..._upcomingMeetings.map((meeting) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _buildMeetingCard(meeting),
                              );
                            }),
                            const SizedBox(height: 16),
                          ],
                          
                          // Expired Meetings
                          if (_expiredMeetings.isNotEmpty) ...[
                            Row(
                              children: [
                                Container(
                                  width: 4,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: Colors.grey,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  'Expired Classes',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${_expiredMeetings.length}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ..._expiredMeetings.map((meeting) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _buildMeetingCard(meeting),
                              );
                            }),
                            const SizedBox(height: 16),
                          ],
                          
                          // Empty State
                          if (totalMeetings == 0)
                            Container(
                              padding: const EdgeInsets.all(40),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.video_call_outlined,
                                    size: 64,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No Zoom Classes Scheduled',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Tap the + button to create your first Zoom class',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          
                          const SizedBox(height: 20),
                          const Center(
                            child: Text(
                              'Developed By Devlk',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryCard({
    required String label,
    required int count,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}