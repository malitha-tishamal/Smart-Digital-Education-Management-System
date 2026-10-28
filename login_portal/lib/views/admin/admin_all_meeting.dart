import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../core/app_colors.dart';

class AdminAllMeetingsScreen extends StatefulWidget {
  const AdminAllMeetingsScreen({super.key});

  @override
  State<AdminAllMeetingsScreen> createState() => _AdminAllMeetingsScreenState();
}

class _AdminAllMeetingsScreenState extends State<AdminAllMeetingsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = true;
  String _adminName = 'Admin';
  String _profileImageUrl = '';

  List<Map<String, dynamic>> _liveMeetings = [];
  List<Map<String, dynamic>> _upcomingMeetings = [];
  List<Map<String, dynamic>> _pastMeetings = [];

  final Map<String, Map<String, dynamic>> _teacherCache = {};
  final Map<String, String> _studentNameCache = {};

  static const String _defaultProfileImageUrl =
      'https://res.cloudinary.com/dqeptzlsb/image/upload/v1782734371/default_il19eg.png';

  @override
  void initState() {
    super.initState();
    _loadAdminData();
  }

  Future<void> _loadAdminData() async {
    setState(() => _isLoading = true);

    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        _adminName = data['name'] ?? 'Admin';
        _profileImageUrl = data['profileImageUrl'] ?? _defaultProfileImageUrl;
      }

      await _fetchAllMeetings();
    } catch (e) {
      print('Error loading admin data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<String> _getStudentName(String studentId) async {
    if (_studentNameCache.containsKey(studentId)) {
      return _studentNameCache[studentId]!;
    }
    
    try {
      final doc = await _firestore.collection('users').doc(studentId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final name = data['name'] ?? 'Unknown Student';
        _studentNameCache[studentId] = name;
        return name;
      }
    } catch (e) {
      print('Error fetching student name: $e');
    }
    
    _studentNameCache[studentId] = 'Unknown Student';
    return 'Unknown Student';
  }

  Future<void> _fetchAllMeetings() async {
    try {
      final meetingsSnapshot = await _firestore
          .collection('zoomMeetings')
          .orderBy('scheduledTime', descending: true)
          .get();

      final now = DateTime.now();

      _liveMeetings.clear();
      _upcomingMeetings.clear();
      _pastMeetings.clear();

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
        }

        final teacherId = data['teacherId'] ?? '';
        
        if (teacherId.isNotEmpty && !_teacherCache.containsKey(teacherId)) {
          await _cacheTeacherDetails(teacherId);
        }

        final joinedStudents = List<String>.from(data['joinedStudents'] ?? []);
        for (var studentId in joinedStudents) {
          if (!_studentNameCache.containsKey(studentId)) {
            await _getStudentName(studentId);
          }
        }

        final meeting = {
          'id': doc.id,
          'title': data['title'] ?? 'Untitled Meeting',
          'academicYear': data['academicYear'] ?? 'N/A',
          'zoomLink': data['zoomLink'] ?? '',
          'scheduledTime': scheduledTime,
          'expiryTime': expiryTime,
          'duration': duration,
          'description': data['description'] ?? '',
          'students': List<String>.from(data['students'] ?? []),
          'joinedStudents': joinedStudents,
          'joinedTimes': Map<String, dynamic>.from(data['joinedTimes'] ?? {}),
          'status': isExpired ? 'expired' : status,
          'teacherId': teacherId,
          'teacherName': data['teacherName'] ?? _teacherCache[teacherId]?['name'] ?? 'Unknown Teacher',
          'teacherEmail': data['teacherEmail'] ?? _teacherCache[teacherId]?['email'] ?? '',
          'teacherProfileImageUrl': _teacherCache[teacherId]?['profileImageUrl'] ?? _defaultProfileImageUrl,
          'createdAt': (data['createdAt'] as Timestamp?)?.toDate(),
        };

        if (isExpired || meeting['status'] == 'expired' || meeting['status'] == 'disabled') {
          _pastMeetings.add(meeting);
        } else if (meeting['status'] == 'active') {
          _liveMeetings.add(meeting);
        } else if (scheduledTime != null && now.isAfter(scheduledTime) && endTime != null && now.isBefore(endTime)) {
          _liveMeetings.add(meeting);
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
      print('Error fetching meetings: $e');
    }
  }

  Future<void> _cacheTeacherDetails(String teacherId) async {
    try {
      final doc = await _firestore.collection('users').doc(teacherId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        _teacherCache[teacherId] = {
          'name': data['name'] ?? 'Unknown',
          'email': data['email'] ?? '',
          'profileImageUrl': data['profileImageUrl'] ?? _defaultProfileImageUrl,
          'stream': data['stream'] ?? '',
        };
      }
    } catch (e) {
      print('Error caching teacher: $e');
    }
  }

  // =============================================
  // ADMIN MEETING ACTIONS
  // =============================================
  
  Future<void> _startMeeting(String meetingId) async {
    try {
      await _firestore.collection('zoomMeetings').doc(meetingId).update({
        'status': 'active',
        'startedAt': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Meeting started!'), backgroundColor: Color(0xFF10B981)),
      );
      await _fetchAllMeetings();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _endMeeting(String meetingId) async {
    try {
      await _firestore.collection('zoomMeetings').doc(meetingId).update({
        'status': 'expired',
        'endedAt': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Meeting ended!'), backgroundColor: Color(0xFF10B981)),
      );
      await _fetchAllMeetings();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _disableMeeting(String meetingId) async {
    try {
      await _firestore.collection('zoomMeetings').doc(meetingId).update({
        'status': 'disabled',
        'disabledAt': FieldValue.serverTimestamp(),
        'disabledBy': _adminName,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Meeting disabled!'), backgroundColor: Color(0xFFF59E0B)),
      );
      await _fetchAllMeetings();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _enableMeeting(String meetingId) async {
    try {
      await _firestore.collection('zoomMeetings').doc(meetingId).update({
        'status': 'upcoming',
        'enabledAt': FieldValue.serverTimestamp(),
        'enabledBy': _adminName,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Meeting re-enabled!'), backgroundColor: Color(0xFF10B981)),
      );
      await _fetchAllMeetings();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteMeeting(String meetingId) async {
    try {
      await _firestore.collection('zoomMeetings').doc(meetingId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Meeting deleted!'), backgroundColor: Color(0xFFEF4444)),
      );
      await _fetchAllMeetings();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
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

  void _showEndConfirmation(Map<String, dynamic> meeting) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('End Meeting'),
        content: Text('End "${meeting['title']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); _endMeeting(meeting['id']); },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('End Meeting'),
          ),
        ],
      ),
    );
  }

  void _showDisableConfirmation(String meetingId, String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Disable Meeting'),
        content: Text('Disable "$title"?'),
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

  void _showEnableConfirmation(String meetingId, String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Re-enable Meeting'),
        content: Text('Re-enable "$title"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); _enableMeeting(meetingId); },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Re-enable'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(String meetingId, String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Meeting'),
        content: Text('Permanently delete "$title"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); _deleteMeeting(meetingId); },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // =============================================
  // FORMATTING HELPERS
  // =============================================

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
    if (difference.inDays > 0) return '${difference.inDays}d ${difference.inHours % 24}h left';
    if (difference.inHours > 0) return '${difference.inHours}h ${difference.inMinutes % 60}m left';
    if (difference.inMinutes > 0) return '${difference.inMinutes}m left';
    return 'Starting soon';
  }

  void _launchZoomMeeting(String link) {
    if (link.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No Zoom link available'), backgroundColor: Colors.orange));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Opening: $link'), backgroundColor: const Color(0xFF6366F1), duration: const Duration(seconds: 3)));
  }

  // =============================================
  // MEETING CARD
  // =============================================

  Widget _buildMeetingCard(Map<String, dynamic> meeting) {
    final scheduledTime = meeting['scheduledTime'] as DateTime?;
    final expiryTime = meeting['expiryTime'] as DateTime?;
    final status = meeting['status'] ?? 'upcoming';
    final studentList = List<String>.from(meeting['students'] ?? []);
    final joinedList = List<String>.from(meeting['joinedStudents'] ?? []);
    final teacherName = meeting['teacherName'] ?? 'Unknown Teacher';
    final teacherImageUrl = meeting['teacherProfileImageUrl'] ?? _defaultProfileImageUrl;

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
      statusText = 'LIVE NOW';
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
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isActive ? accentColor.withOpacity(0.3) : const Color(0xFFE5E7EB), width: isActive ? 1.5 : 1),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                color: bgColor,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: accentColor.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
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

              // Body
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Teacher Info
                    Row(
                      children: [
                        CircleAvatar(radius: 16, backgroundImage: NetworkImage(teacherImageUrl), backgroundColor: Colors.grey.shade200, child: teacherImageUrl == _defaultProfileImageUrl ? const Icon(Icons.person, size: 16, color: Colors.white) : null),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(teacherName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
                            Text('Teacher', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                          ]),
                        ),
                        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Text('AL ${meeting['academicYear'] ?? 'N/A'}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF8B5CF6)))),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Title
                    Text(meeting['title'] ?? 'Untitled Meeting', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF111827), height: 1.2), maxLines: 2, overflow: TextOverflow.ellipsis),

                    if (meeting['description'] != null && meeting['description'].toString().isNotEmpty)
                      Padding(padding: const EdgeInsets.only(top: 4), child: Text(meeting['description'], style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)), maxLines: 2, overflow: TextOverflow.ellipsis)),

                    const SizedBox(height: 10),

                    // Info Chips
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      _buildInfoChip(Icons.access_time, '${meeting['duration'] ?? 60}m', const Color(0xFFF59E0B)),
                      _buildInfoChip(Icons.people, '${studentList.length} Students', const Color(0xFF3B82F6)),
                      _buildInfoChip(Icons.calendar_today, _formatDateTimeShort(scheduledTime), const Color(0xFF6366F1)),
                      if (expiryTime != null) _buildInfoChip(Icons.timer_off, 'Exp: ${_formatDateTimeShort(expiryTime)}', const Color(0xFFEF4444)),
                    ]),

                    // Attendance Bar
                    if ((isActive || isExpired) && studentList.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Column(children: [
                          Row(children: [
                            const Icon(Icons.check_circle, size: 12, color: Color(0xFF10B981)),
                            const SizedBox(width: 4),
                            Text('${joinedList.length}/${studentList.length} joined', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF6B7280))),
                            const Spacer(),
                            Text('${studentList.isEmpty ? 0 : (joinedList.length / studentList.length * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF10B981))),
                          ]),
                          const SizedBox(height: 4),
                          ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: studentList.isEmpty ? 0 : joinedList.length / studentList.length, backgroundColor: const Color(0xFFE5E7EB), valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)), minHeight: 3)),
                        ]),
                      ),

                    const SizedBox(height: 10),

                    // =============================================
                    // SUPER COMPACT ACTION BUTTONS
                    // =============================================
                    Row(children: [
                      // Primary Action
                      if (isActive) _buildTinyChipButton(label: 'Join', icon: Icons.video_call, color: const Color(0xFF10B981), onTap: () => _launchZoomMeeting(meeting['zoomLink'] ?? '')),
                      if (isUpcoming) _buildTinyChipButton(label: 'Start', icon: Icons.play_arrow, color: const Color(0xFF10B981), onTap: () => _showStartConfirmation(meeting)),
                      if (isDisabled) _buildTinyChipButton(label: 'Enable', icon: Icons.refresh, color: const Color(0xFF10B981), onTap: () => _showEnableConfirmation(meeting['id'], meeting['title'] ?? '')),
                      if (isExpired) _buildTinyChipButton(label: 'View', icon: Icons.visibility_outlined, color: const Color(0xFF6B7280), onTap: () => _showMeetingDetails(meeting)),
                      
                      const Spacer(),
                      
                      // Management Icons
                      if (isActive) _buildTinyIconButton(icon: Icons.stop_circle_outlined, color: const Color(0xFFEF4444), onTap: () => _showEndConfirmation(meeting), tooltip: 'End'),
                      if (isUpcoming || isActive) _buildTinyIconButton(icon: Icons.block_outlined, color: const Color(0xFFF59E0B), onTap: () => _showDisableConfirmation(meeting['id'], meeting['title'] ?? ''), tooltip: 'Disable'),
                      _buildTinyIconButton(icon: Icons.info_outline, color: const Color(0xFF6366F1), onTap: () => _showMeetingDetails(meeting), tooltip: 'Details'),
                      _buildTinyIconButton(icon: Icons.delete_outline, color: const Color(0xFFDC2626), onTap: () => _showDeleteConfirmation(meeting['id'], meeting['title'] ?? ''), tooltip: 'Delete'),
                    ]),
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
  // MEETING DETAILS MODAL
  // =============================================

  void _showMeetingDetails(Map<String, dynamic> meeting) async {
    final scheduledTime = meeting['scheduledTime'] as DateTime?;
    final expiryTime = meeting['expiryTime'] as DateTime?;
    final studentList = List<String>.from(meeting['students'] ?? []);
    final joinedList = List<String>.from(meeting['joinedStudents'] ?? []);
    final joinedTimes = Map<String, dynamic>.from(meeting['joinedTimes'] ?? {});
    final teacherName = meeting['teacherName'] ?? 'Unknown Teacher';

    for (var studentId in joinedList) {
      if (!_studentNameCache.containsKey(studentId)) {
        await _getStudentName(studentId);
      }
    }
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.92,
        minChildSize: 0.5,
        expand: false,
        builder: (ctx, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFD1D5DB), borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Row(children: [
                Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.video_call, color: Color(0xFF6366F1), size: 22)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(meeting['title'] ?? 'Meeting Details', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                  Text('By $teacherName • AL ${meeting['academicYear'] ?? 'N/A'}', style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                ])),
                IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close, color: Color(0xFF9CA3AF))),
              ]),
              const Divider(height: 24),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE5E7EB))),
                      child: Column(children: [
                        _detailRow(Icons.calendar_today, 'Scheduled', _formatDateTime(scheduledTime), const Color(0xFF3B82F6)),
                        const Divider(height: 16),
                        _detailRow(Icons.timer, 'Duration', '${meeting['duration'] ?? 60} minutes', const Color(0xFFF59E0B)),
                        const Divider(height: 16),
                        _detailRow(Icons.timer_off, 'Expires', _formatDateTime(expiryTime), const Color(0xFFEF4444)),
                        const Divider(height: 16),
                        _detailRow(Icons.info, 'Status', meeting['status'] ?? 'N/A', const Color(0xFF10B981)),
                        if (meeting['zoomLink']?.isNotEmpty == true) ...[
                          const Divider(height: 16),
                          _detailRow(Icons.link, 'Zoom Link', meeting['zoomLink'], const Color(0xFF6366F1)),
                        ],
                      ]),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFBBF7D0))),
                      child: Row(children: [
                        const Icon(Icons.people, color: Color(0xFF10B981), size: 20),
                        const SizedBox(width: 10),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('Student Attendance', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
                          Text('${joinedList.length} of ${studentList.length} joined', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                        ]),
                        const Spacer(),
                        Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(12)), child: Text('${studentList.isEmpty ? 0 : (joinedList.length / studentList.length * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white))),
                      ]),
                    ),
                    const SizedBox(height: 16),
                    Row(children: [
                      const Icon(Icons.check_circle, size: 18, color: Color(0xFF10B981)),
                      const SizedBox(width: 8),
                      Text('Joined Students (${joinedList.length})', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
                    ]),
                    if (joinedList.isEmpty)
                      Container(margin: const EdgeInsets.only(top: 12), padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE5E7EB))), child: const Center(child: Text('No students joined yet', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13))))
                    else
                      ...joinedList.map((studentId) {
                        final joinTimestamp = joinedTimes[studentId];
                        DateTime? joinTime;
                        if (joinTimestamp is Timestamp) joinTime = joinTimestamp.toDate();
                        final studentName = _studentNameCache[studentId] ?? 'Loading...';
                        final initials = studentName.split(' ').take(2).map((e) => e.isNotEmpty ? e[0].toUpperCase() : '').join();
                        return Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE5E7EB))),
                          child: Row(children: [
                            Container(width: 36, height: 36, decoration: BoxDecoration(gradient: LinearGradient(colors: [const Color(0xFF10B981).withOpacity(0.2), const Color(0xFF059669).withOpacity(0.1)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(10)), child: Center(child: Text(initials, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF059669))))),
                            const SizedBox(width: 10),
                            Expanded(child: Text(studentName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF111827)))),
                            if (joinTime != null) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Text(DateFormat('hh:mm a').format(joinTime), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF10B981)))),
                          ]),
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

  // =============================================
  // UI HELPERS
  // =============================================

  Widget _detailRow(IconData icon, String label, String value, Color color) {
    return Row(children: [
      Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Icon(icon, size: 14, color: color)),
      const SizedBox(width: 10),
      Text('$label:', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF6B7280))),
      const SizedBox(width: 6),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF111827)), textAlign: TextAlign.end, overflow: TextOverflow.ellipsis)),
    ]);
  }

  Widget _buildInfoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withOpacity(0.15))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 11, color: color), const SizedBox(width: 4), Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color))]),
    );
  }

  Widget _buildTinyChipButton({required String label, required IconData icon, required Color color, required VoidCallback onTap}) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 12, color: color), const SizedBox(width: 3), Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: color))]),
        ),
      ),
    );
  }

  Widget _buildTinyIconButton({required IconData icon, required Color color, required VoidCallback onTap, String? tooltip}) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(padding: const EdgeInsets.all(5), child: Icon(icon, size: 14, color: color)),
        ),
      ),
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

  // =============================================
  // HEADER
  // =============================================

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
          IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28), onPressed: () => Navigator.pop(context), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
          const Spacer(),
          Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_adminName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 4),
            const Text('Logged in as: Admin', style: TextStyle(fontSize: 12, color: Colors.white70)),
          ]),
          const Spacer(),
          CircleAvatar(radius: 40, backgroundImage: NetworkImage(_profileImageUrl), backgroundColor: Colors.grey.shade200, onBackgroundImageError: (_, __) {}, child: _profileImageUrl == _defaultProfileImageUrl ? const Icon(Icons.person, size: 40, color: Colors.white) : null),
        ]),
        const SizedBox(height: 20),
        const Text('All Meetings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
      ]),
    );
  }

  // =============================================
  // BUILD
  // =============================================

  @override
  Widget build(BuildContext context) {
    final totalMeetings = _liveMeetings.length + _upcomingMeetings.length + _pastMeetings.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryPurple))
          : Column(children: [
              _buildHeader(),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _fetchAllMeetings,
                  color: AppColors.primaryPurple,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        _buildSummaryCard('Total', totalMeetings, const Color(0xFF6366F1), Icons.video_call),
                        const SizedBox(width: 10),
                        _buildSummaryCard('Live', _liveMeetings.length, const Color(0xFF10B981), Icons.live_tv),
                        const SizedBox(width: 10),
                        _buildSummaryCard('Upcoming', _upcomingMeetings.length, const Color(0xFF8B5CF6), Icons.schedule),
                        const SizedBox(width: 10),
                        _buildSummaryCard('Past', _pastMeetings.length, const Color(0xFF9CA3AF), Icons.history),
                      ]),
                      const SizedBox(height: 20),
                      if (_liveMeetings.isNotEmpty) ...[
                        _buildSectionHeader('🔴 Live Now', const Color(0xFF10B981), _liveMeetings.length),
                        const SizedBox(height: 10),
                        ..._liveMeetings.map((m) => _buildMeetingCard(m)),
                      ],
                      if (_upcomingMeetings.isNotEmpty) ...[
                        _buildSectionHeader('📅 Upcoming', const Color(0xFF6366F1), _upcomingMeetings.length),
                        const SizedBox(height: 10),
                        ..._upcomingMeetings.map((m) => _buildMeetingCard(m)),
                      ],
                      if (_pastMeetings.isNotEmpty) ...[
                        _buildSectionHeader('📋 Past Meetings', const Color(0xFF9CA3AF), _pastMeetings.length),
                        const SizedBox(height: 10),
                        ..._pastMeetings.map((m) => _buildMeetingCard(m)),
                      ],
                      if (totalMeetings == 0)
                        Container(
                          padding: const EdgeInsets.all(40),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5E7EB))),
                          child: Column(children: [
                            Icon(Icons.video_call_outlined, size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            const Text('No Meetings Found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF374151))),
                            const SizedBox(height: 8),
                            const Text('No teachers have created any Zoom classes yet', style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)), textAlign: TextAlign.center),
                          ]),
                        ),
                      const SizedBox(height: 20),
                    ]),
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(color: const Color(0xFFF9FAFB), border: Border(top: BorderSide(color: Colors.grey.shade200, width: 0.5))),
                child: const Center(child: Text('Developed By Devlk', style: TextStyle(fontSize: 14, color: Colors.black45, fontWeight: FontWeight.w400))),
              ),
            ]),
    );
  }
}