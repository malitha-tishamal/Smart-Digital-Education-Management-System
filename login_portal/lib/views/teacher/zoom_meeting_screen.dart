import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/app_colors.dart';

class ZoomMeetingScreen extends StatefulWidget {
  const ZoomMeetingScreen({super.key});

  @override
  State<ZoomMeetingScreen> createState() => _ZoomMeetingScreenState();
}

class _ZoomMeetingScreenState extends State<ZoomMeetingScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = true;
  String _teacherName = '';
  String _teacherEmail = '';
  String _teacherStream = '';
  List<String> _teacherSubjects = [];
  List<String> _academicYears = [];
  Map<String, List<String>> _studentsByYear = {};

  // Meeting lists
  List<Map<String, dynamic>> _activeMeetings = [];
  List<Map<String, dynamic>> _upcomingMeetings = [];
  List<Map<String, dynamic>> _expiredMeetings = [];

  // Create meeting controllers
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _zoomLinkController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  String _selectedYear = '';
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = TimeOfDay.now();
  int _selectedDuration = 60;
  int _selectedBatches = 1;
  int _currentBatch = 1;

  @override
  void initState() {
    super.initState();
    _loadTeacherData();
  }

  Future<void> _loadTeacherData() async {
    setState(() => _isLoading = true);

    final user = _auth.currentUser;
    if (user == null) {
      Navigator.pop(context);
      return;
    }

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) {
        Navigator.pop(context);
        return;
      }

      final data = doc.data() as Map<String, dynamic>;
      _teacherName = data['name'] ?? 'Teacher';
      _teacherEmail = data['email'] ?? user.email ?? '';
      _teacherStream = data['stream'] ?? '';
      _teacherSubjects = List<String>.from(data['subjects'] ?? []);

      await _fetchStudents();
      await _fetchMeetings();
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
              'email': data['email'] ?? '',
              'stream': data['stream'] ?? '',
              'subjects': List<String>.from(data['subjects'] ?? []),
              'academicYear': data['academicYear'] ?? '2024',
              'studentId': data['studentId'] ?? '',
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
      for (var student in filteredStudents) {
        final year = student['academicYear'] ?? '2024';
        if (!_studentsByYear.containsKey(year)) {
          _studentsByYear[year] = [];
        }
        _studentsByYear[year]!.add(student['id']);
      }

      _academicYears = _studentsByYear.keys.toList()..sort((a, b) => b.compareTo(a));
      if (_academicYears.isNotEmpty) {
        _selectedYear = _academicYears[0];
      }
    } catch (e) {
      print('Error fetching students: $e');
    }
  }

  Future<void> _fetchMeetings() async {
    try {
      final teacherId = _auth.currentUser?.uid;
      if (teacherId == null) return;

      final meetingsSnapshot = await _firestore
          .collection('zoomMeetings')
          .where('teacherId', isEqualTo: teacherId)
          .orderBy('scheduledTime', descending: false)
          .get();

      final now = DateTime.now();
      
      _activeMeetings.clear();
      _upcomingMeetings.clear();
      _expiredMeetings.clear();

      for (var doc in meetingsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final scheduledTime = (data['scheduledTime'] as Timestamp?)?.toDate();
        final expiryTime = (data['expiryTime'] as Timestamp?)?.toDate();
        final duration = data['duration'] ?? 60;
        final endTime = scheduledTime?.add(Duration(minutes: duration));
        
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
          'students': List<String>.from(data['students'] ?? []),
          'status': data['status'] ?? 'upcoming',
          'teacherName': data['teacherName'] ?? _teacherName,
          'teacherEmail': data['teacherEmail'] ?? _teacherEmail,
        };

        // Determine meeting status
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

      setState(() {});
    } catch (e) {
      print('Error fetching meetings: $e');
    }
  }

  Future<void> _createMeeting() async {
    if (_titleController.text.isEmpty || _zoomLinkController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedYear.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an academic year'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final scheduledDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      final studentIds = _studentsByYear[_selectedYear] ?? [];
      final expiryTime = scheduledDateTime.add(
        Duration(minutes: _selectedDuration + 30)
      );

      await _firestore.collection('zoomMeetings').add({
        'teacherId': _auth.currentUser?.uid,
        'title': _titleController.text,
        'zoomLink': _zoomLinkController.text,
        'description': _descriptionController.text,
        'academicYear': _selectedYear,
        'scheduledTime': Timestamp.fromDate(scheduledDateTime),
        'expiryTime': Timestamp.fromDate(expiryTime),
        'duration': _selectedDuration,
        'totalBatches': _selectedBatches,
        'batchNumber': 1,
        'students': studentIds,
        'status': 'upcoming',
        'createdAt': FieldValue.serverTimestamp(),
        'teacherName': _teacherName,
        'teacherEmail': _teacherEmail,
      });

      // Clear form
      _titleController.clear();
      _zoomLinkController.clear();
      _descriptionController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Zoom meeting created successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      await _fetchMeetings();
      Navigator.pop(context); // Close dialog if open
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating meeting: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
      await _fetchMeetings();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting meeting: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateMeetingStatus(String meetingId, String status) async {
    try {
      await _firestore.collection('zoomMeetings').doc(meetingId).update({
        'status': status,
      });
      await _fetchMeetings();
    } catch (e) {
      print('Error updating meeting status: $e');
    }
  }

  // ---- Build Meeting Card ----
  Widget _buildMeetingCard(Map<String, dynamic> meeting) {
    final scheduledTime = meeting['scheduledTime'] as DateTime?;
    final expiryTime = meeting['expiryTime'] as DateTime?;
    final now = DateTime.now();
    final isActive = meeting['status'] == 'active' || 
                     (scheduledTime != null && 
                      now.isAfter(scheduledTime) && 
                      expiryTime != null && 
                      now.isBefore(expiryTime));
    final isUpcoming = meeting['status'] == 'upcoming' && 
                       scheduledTime != null && 
                       now.isBefore(scheduledTime);
    final isExpired = meeting['status'] == 'expired' || 
                      (expiryTime != null && now.isAfter(expiryTime));

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

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 12),
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isActive ? Icons.video_call : Icons.video_call_outlined,
                      color: statusColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          meeting['title'] ?? 'Zoom Meeting',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.darkText,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Year ${meeting['academicYear'] ?? '2024'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 12, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (meeting['description'] != null && meeting['description'].toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
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
              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    scheduledTime != null 
                        ? '${scheduledTime.day}/${scheduledTime.month}/${scheduledTime.year} ${scheduledTime.hour.toString().padLeft(2, '0')}:${scheduledTime.minute.toString().padLeft(2, '0')}'
                        : 'Not scheduled',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.timer, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    '${meeting['duration'] ?? 60} min',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.groups, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    'Batch ${meeting['batchNumber'] ?? 1}/${meeting['totalBatches'] ?? 1}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.school, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    '${(meeting['students'] as List).length} students',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (isActive)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _launchZoomMeeting(meeting['zoomLink'] ?? '');
                        },
                        icon: const Icon(Icons.video_call, size: 16),
                        label: const Text('Join Now'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  if (isUpcoming)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          _showMeetingDetails(meeting);
                        },
                        icon: const Icon(Icons.info_outline, size: 16),
                        label: const Text('Details'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryPurple,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
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
                        icon: const Icon(Icons.history, size: 16),
                        label: const Text('View'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey.shade500,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  PopupMenuButton(
                    icon: Icon(Icons.more_vert, color: Colors.grey.shade500),
                    onSelected: (value) {
                      if (value == 'delete') {
                        _showDeleteConfirmation(meeting['id']);
                      } else if (value == 'edit') {
                        // Edit functionality
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 16),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red, size: 16),
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
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showMeetingDetails(Map<String, dynamic> meeting) {
    final scheduledTime = meeting['scheduledTime'] as DateTime?;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(meeting['title'] ?? 'Meeting Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (meeting['description'] != null && meeting['description'].toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  meeting['description'],
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            _buildDetailRow(Icons.calendar_today, 'Academic Year', meeting['academicYear'] ?? '2024'),
            _buildDetailRow(Icons.access_time, 'Scheduled', 
                scheduledTime != null 
                    ? '${scheduledTime.day}/${scheduledTime.month}/${scheduledTime.year} ${scheduledTime.hour.toString().padLeft(2, '0')}:${scheduledTime.minute.toString().padLeft(2, '0')}'
                    : 'Not scheduled'),
            _buildDetailRow(Icons.timer, 'Duration', '${meeting['duration'] ?? 60} minutes'),
            _buildDetailRow(Icons.groups, 'Batch', '${meeting['batchNumber'] ?? 1}/${meeting['totalBatches'] ?? 1}'),
            _buildDetailRow(Icons.school, 'Students', '${(meeting['students'] as List).length} students'),
            if (meeting['zoomLink'] != null && meeting['zoomLink'].toString().isNotEmpty)
              _buildDetailRow(Icons.link, 'Zoom Link', meeting['zoomLink']),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (meeting['status'] == 'active' || 
              (scheduledTime != null && 
               DateTime.now().isAfter(scheduledTime) &&
               meeting['expiryTime'] != null &&
               DateTime.now().isBefore(meeting['expiryTime'])))
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _launchZoomMeeting(meeting['zoomLink'] ?? '');
              },
              icon: const Icon(Icons.video_call),
              label: const Text('Join Now'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
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
          const SizedBox(width: 8),
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
    if (link.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Zoom link not available'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    // For now, show a snackbar with the link
    // You can use url_launcher package to actually open the link
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening Zoom: $link'),
        backgroundColor: AppColors.primaryPurple,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Copy Link',
          onPressed: () {
            // Copy to clipboard
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Link copied to clipboard'),
                backgroundColor: Colors.green,
              ),
            );
          },
        ),
      ),
    );
  }

  // ---- Create Meeting Dialog ----
  Future<void> _showCreateMeetingDialog() async {
    _titleController.clear();
    _zoomLinkController.clear();
    _descriptionController.clear();
    _selectedDate = DateTime.now().add(const Duration(days: 1));
    _selectedTime = TimeOfDay.now();
    _selectedDuration = 60;
    _selectedBatches = 1;
    _currentBatch = 1;

    if (_academicYears.isNotEmpty) {
      _selectedYear = _academicYears[0];
    }

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.video_call, color: AppColors.primaryPurple),
              SizedBox(width: 10),
              Text('Create Zoom Class'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Meeting Title *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.title),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _zoomLinkController,
                  decoration: const InputDecoration(
                    labelText: 'Zoom Meeting Link *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.link),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.description),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedYear,
                  decoration: const InputDecoration(
                    labelText: 'Academic Year *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  items: _academicYears.map((year) {
                    return DropdownMenuItem(
                      value: year,
                      child: Text('Year $year'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _selectedYear = value);
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (date != null) {
                            setState(() => _selectedDate = date);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 16, color: AppColors.primaryPurple),
                              const SizedBox(width: 8),
                              Text(
                                '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                                style: const TextStyle(fontSize: 14),
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
                            initialTime: _selectedTime,
                          );
                          if (time != null) {
                            setState(() => _selectedTime = time);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.access_time, size: 16, color: AppColors.primaryPurple),
                              const SizedBox(width: 8),
                              Text(
                                _selectedTime.format(context),
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _selectedDuration,
                        decoration: const InputDecoration(
                          labelText: 'Duration',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.timer),
                        ),
                        items: [30, 45, 60, 90, 120].map((value) {
                          return DropdownMenuItem(
                            value: value,
                            child: Text('$value min'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) setState(() => _selectedDuration = value);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _selectedBatches,
                        decoration: const InputDecoration(
                          labelText: 'Batches',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.groups),
                        ),
                        items: [1, 2, 3, 4, 5].map((value) {
                          return DropdownMenuItem(
                            value: value,
                            child: Text('$value batches'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) setState(() => _selectedBatches = value);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.primaryPurple, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${_studentsByYear[_selectedYear]?.length ?? 0} students will be assigned to this meeting',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _createMeeting,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPurple,
                foregroundColor: Colors.white,
              ),
              child: const Text('Create Meeting'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalMeetings = _activeMeetings.length + _upcomingMeetings.length + _expiredMeetings.length;

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Zoom Classes'),
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              setState(() => _isLoading = true);
              await _fetchMeetings();
              setState(() => _isLoading = false);
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateMeetingDialog,
        icon: const Icon(Icons.add),
        label: const Text('New Class'),
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryPurple))
          : RefreshIndicator(
              onRefresh: _fetchMeetings,
              color: AppColors.primaryPurple,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Summary Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primaryPurple.withOpacity(0.1),
                            AppColors.primaryPurple.withOpacity(0.02),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.primaryPurple.withOpacity(0.15),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildSummaryItem(
                            label: 'Total',
                            count: totalMeetings,
                            color: AppColors.primaryPurple,
                            icon: Icons.video_call,
                          ),
                          _buildSummaryItem(
                            label: 'Live',
                            count: _activeMeetings.length,
                            color: const Color(0xFF059669),
                            icon: Icons.live_tv,
                          ),
                          _buildSummaryItem(
                            label: 'Upcoming',
                            count: _upcomingMeetings.length,
                            color: const Color(0xFF2563EB),
                            icon: Icons.schedule,
                          ),
                          _buildSummaryItem(
                            label: 'Expired',
                            count: _expiredMeetings.length,
                            color: Colors.grey,
                            icon: Icons.cancel,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Active Meetings
                    if (_activeMeetings.isNotEmpty) ...[
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 24,
                            decoration: BoxDecoration(
                              color: const Color(0xFF059669),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Live Now',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF059669),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
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
                      ..._activeMeetings.map((meeting) => _buildMeetingCard(meeting)),
                      const SizedBox(height: 16),
                    ],

                    // Upcoming Meetings
                    if (_upcomingMeetings.isNotEmpty) ...[
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 24,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Upcoming Classes',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
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
                      ..._upcomingMeetings.map((meeting) => _buildMeetingCard(meeting)),
                      const SizedBox(height: 16),
                    ],

                    // Expired Meetings
                    if (_expiredMeetings.isNotEmpty) ...[
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.grey,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Expired Classes',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
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
                      ..._expiredMeetings.map((meeting) => _buildMeetingCard(meeting)),
                      const SizedBox(height: 16),
                    ],

                    // Empty State
                    if (totalMeetings == 0)
                      Container(
                        padding: const EdgeInsets.all(40),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
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
                              'No Zoom Classes',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Create your first Zoom class by tapping the + button',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSummaryItem({
    required String label,
    required int count,
    required Color color,
    required IconData icon,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
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
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade500,
          ),
        ),
      ],
    );
  }
}