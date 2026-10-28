import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../core/app_colors.dart';

class UserClassDetailScreen extends StatefulWidget {
  final Map<String, dynamic> enrollment;

  const UserClassDetailScreen({super.key, required this.enrollment});

  @override
  State<UserClassDetailScreen> createState() => _UserClassDetailScreenState();
}

class _UserClassDetailScreenState extends State<UserClassDetailScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _activeMeetings = [];
  List<Map<String, dynamic>> _upcomingMeetings = [];
  List<Map<String, dynamic>> _expiredMeetings = [];
  bool _isLoading = true;
  String _studentId = '';

  // Sri Lanka time (UTC+5:30)
  DateTime get _nowInSriLanka {
    return DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
  }

  @override
  void initState() {
    super.initState();
    _studentId = _auth.currentUser?.uid ?? '';
    _fetchMeetings();
  }

  Future<void> _fetchMeetings() async {
    try {
      final classId = widget.enrollment['classId'] as String;
      final studentId = _auth.currentUser?.uid;

      final meetingsSnapshot = await _firestore
          .collection('zoomMeetings')
          .where('teacherId', isEqualTo: classId)
          .get();

      final now = _nowInSriLanka;
      
      _activeMeetings.clear();
      _upcomingMeetings.clear();
      _expiredMeetings.clear();

      for (var doc in meetingsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final scheduledTime = (data['scheduledTime'] as Timestamp?)?.toDate();
        final expiryTime = (data['expiryTime'] as Timestamp?)?.toDate();
        final duration = data['duration'] ?? 60;
        final status = data['status'] ?? 'upcoming';
        final students = List<String>.from(data['students'] ?? []);
        final joinedStudents = List<String>.from(data['joinedStudents'] ?? []);
        final joinedTimes = Map<String, dynamic>.from(data['joinedTimes'] ?? {});
        
        DateTime? endTime;
        if (scheduledTime != null) {
          endTime = scheduledTime.add(Duration(minutes: duration));
        }

        if (!students.contains(studentId)) continue;

        final meeting = {
          'id': doc.id,
          'title': data['title'] ?? 'Zoom Meeting',
          'academicYear': data['academicYear'] ?? '2024',
          'zoomLink': data['zoomLink'] ?? '',
          'scheduledTime': scheduledTime,
          'expiryTime': expiryTime,
          'duration': duration,
          'description': data['description'] ?? '',
          'students': students,
          'joinedStudents': joinedStudents,
          'joinedTimes': joinedTimes,
          'status': status,
          'teacherName': data['teacherName'] ?? '',
        };

        bool isExpired = false;
        if (expiryTime != null && now.isAfter(expiryTime)) {
          isExpired = true;
        }

        if (isExpired || meeting['status'] == 'expired' || meeting['status'] == 'disabled') {
          _expiredMeetings.add(meeting);
        } else if (meeting['status'] == 'active') {
          _activeMeetings.add(meeting);
        } else if (scheduledTime != null) {
          if (endTime != null && now.isAfter(scheduledTime) && now.isBefore(endTime)) {
            _activeMeetings.add(meeting);
          } else if (now.isBefore(scheduledTime)) {
            _upcomingMeetings.add(meeting);
          } else if (endTime != null && now.isAfter(endTime)) {
            _expiredMeetings.add(meeting);
          } else {
            _upcomingMeetings.add(meeting);
          }
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

      setState(() => _isLoading = false);
    } catch (e) {
      print('Error fetching meetings: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _joinMeeting(Map<String, dynamic> meeting) async {
    try {
      final studentId = _auth.currentUser?.uid;
      if (studentId == null) return;

      final joinedStudents = List<String>.from(meeting['joinedStudents'] ?? []);
      if (joinedStudents.contains(studentId)) {
        _launchZoomLink(meeting['zoomLink'] ?? '');
        return;
      }

      await _firestore.collection('zoomMeetings').doc(meeting['id']).update({
        'joinedStudents': FieldValue.arrayUnion([studentId]),
        'joinedTimes.$studentId': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Attendance marked! Opening meeting...'),
          backgroundColor: Color(0xFF10B981),
          duration: Duration(seconds: 2),
        ),
      );

      _launchZoomLink(meeting['zoomLink'] ?? '');
      await _fetchMeetings();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _launchZoomLink(String link) {
    if (link.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No Zoom link available'), backgroundColor: Colors.orange),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening: $link'),
        backgroundColor: const Color(0xFF2563EB),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  bool _hasJoined(dynamic meetingId, List<String> joinedStudents) {
    return joinedStudents.contains(_studentId);
  }

  String _formatDate(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';
    return DateFormat('MMM dd').format(dateTime);
  }

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    return DateFormat('hh:mm a').format(dateTime);
  }

  String _getTimeRemaining(DateTime? dateTime) {
    if (dateTime == null) return '';
    final now = _nowInSriLanka;
    final difference = dateTime.difference(now);
    if (difference.isNegative) return 'Started';
    if (difference.inDays > 0) return 'in ${difference.inDays}d';
    if (difference.inHours > 0) return 'in ${difference.inHours}h';
    if (difference.inMinutes > 0) return 'in ${difference.inMinutes}m';
    return 'Soon';
  }

  // =============================================
  // HEADER
  // =============================================
  Widget _buildHeader() {
    final teacherName = widget.enrollment['teacherName'] ?? 'Teacher';
    final teacherEmail = widget.enrollment['teacherEmail'] ?? '';
    final teacherStream = widget.enrollment['teacherStream'] ?? '';
    final teacherImageUrl = widget.enrollment['teacherProfileImageUrl'] ?? '';

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
          BoxShadow(color: Color(0x10000000), blurRadius: 15, offset: Offset(0, 5)),
        ],
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
                    onPressed: () => Navigator.pop(context),
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(teacherName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 2),
                      Text(teacherEmail, style: const TextStyle(fontSize: 11, color: Colors.white70), overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                CircleAvatar(
                  radius: 32,
                  backgroundImage: teacherImageUrl.isNotEmpty ? NetworkImage(teacherImageUrl) : null,
                  backgroundColor: Colors.white.withOpacity(0.3),
                  child: teacherImageUrl.isEmpty ? const Icon(Icons.person, size: 32, color: Colors.white) : null,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.school, color: Colors.white, size: 13),
                  const SizedBox(width: 5),
                  Text('Stream: $teacherStream', style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text('Class Meetings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
          ],
        ),
      ),
    );
  }

  // =============================================
  // STATS CARDS
  // =============================================
  Widget _buildStatsRow() {
    final totalMeetings = _activeMeetings.length + _upcomingMeetings.length + _expiredMeetings.length;
    final attendedCount = _expiredMeetings.where((m) {
      final joined = List<String>.from(m['joinedStudents'] ?? []);
      return joined.contains(_studentId);
    }).length + _activeMeetings.where((m) {
      final joined = List<String>.from(m['joinedStudents'] ?? []);
      return joined.contains(_studentId);
    }).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              icon: Icons.favorite_rounded,
              title: 'Live',
              value: '${_activeMeetings.length}',
              color: const Color(0xFF10B981),
              bgColor: const Color(0xFFECFDF5),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildStatCard(
              icon: Icons.schedule_rounded,
              title: 'Upcoming',
              value: '${_upcomingMeetings.length}',
              color: const Color(0xFFF59E0B),
              bgColor: const Color(0xFFFFFBEB),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildStatCard(
              icon: Icons.check_circle_rounded,
              title: 'Attended',
              value: '$attendedCount/$totalMeetings',
              color: const Color(0xFFEF4444),
              bgColor: const Color(0xFFFEF2F2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(title, style: TextStyle(fontSize: 10, color: color.withOpacity(0.7), fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // =============================================
  // MEETING CARD
  // =============================================
  Widget _buildMeetingCard(Map<String, dynamic> meeting) {
    final scheduledTime = meeting['scheduledTime'] as DateTime?;
    final expiryTime = meeting['expiryTime'] as DateTime?;
    final status = meeting['status'] ?? 'upcoming';
    final joinedStudents = List<String>.from(meeting['joinedStudents'] ?? []);
    final joinedTimes = Map<String, dynamic>.from(meeting['joinedTimes'] ?? {});
    final hasJoined = _hasJoined(meeting['id'], joinedStudents);
    final now = _nowInSriLanka;
    final duration = meeting['duration'] ?? 60;
    final endTime = scheduledTime?.add(Duration(minutes: duration));
    
    final isUpcoming = status == 'approved' || status == 'upcoming';
    final isActive = status == 'active';
    final isExpired = status == 'expired' || status == 'disabled';
    final isTimeStarted = scheduledTime != null && now.isAfter(scheduledTime);
    final isTimeEnded = endTime != null && now.isAfter(endTime);
    final shouldBeLive = isTimeStarted && !isTimeEnded && !isExpired;
    final displayAsActive = isActive || (shouldBeLive && isUpcoming);

    DateTime? studentJoinTime;
    if (hasJoined && joinedTimes[_studentId] != null) {
      final timestamp = joinedTimes[_studentId];
      if (timestamp is Timestamp) {
        studentJoinTime = timestamp.toDate();
      }
    }

    Color cardBgColor;
    Color accentColor;
    Color statusBgColor;
    String statusText;
    IconData statusIcon;
    String buttonText;
    IconData buttonIcon;
    Color buttonColor;
    Color buttonBgColor;
    
    if (displayAsActive) {
      cardBgColor = const Color(0xFFF0FDF4);
      accentColor = const Color(0xFF10B981);
      statusBgColor = const Color(0xFF059669);
      statusText = 'LIVE NOW';
      statusIcon = Icons.fiber_manual_record;
      buttonText = hasJoined ? 'Join Again' : 'Join Now';
      buttonIcon = hasJoined ? Icons.video_call : Icons.login;
      buttonColor = Colors.white;
      buttonBgColor = const Color(0xFF059669);
    } else if (isUpcoming) {
      cardBgColor = const Color(0xFFFFFBEB);
      accentColor = const Color(0xFFF59E0B);
      statusBgColor = const Color(0xFFD97706);
      statusText = 'UPCOMING';
      statusIcon = Icons.schedule;
      buttonText = 'Not Started Yet';
      buttonIcon = Icons.hourglass_empty;
      buttonColor = const Color(0xFFD97706);
      buttonBgColor = const Color(0xFFFEF3C7);
    } else {
      cardBgColor = const Color(0xFFFEF2F2);
      accentColor = const Color(0xFFEF4444);
      statusBgColor = const Color(0xFFDC2626);
      statusText = hasJoined ? 'ATTENDED' : 'MISSED';
      statusIcon = hasJoined ? Icons.check_circle : Icons.cancel;
      buttonText = hasJoined ? 'Class Attended!' : 'You Missed This Class';
      buttonIcon = hasJoined ? Icons.celebration : Icons.sentiment_dissatisfied;
      buttonColor = hasJoined ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
      buttonBgColor = hasJoined ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accentColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(color: accentColor.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusBgColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: statusBgColor.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 12, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(statusText, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.5)),
                    ],
                  ),
                ),
                const Spacer(),
                if (!displayAsActive && isUpcoming && scheduledTime != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.timer, size: 12, color: accentColor),
                        const SizedBox(width: 4),
                        Text(_getTimeRemaining(scheduledTime), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: accentColor)),
                      ],
                    ),
                  ),
                if (displayAsActive)
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      color: accentColor,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: accentColor.withOpacity(0.5), blurRadius: 6)],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              meeting['title'] ?? 'Zoom Meeting',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A), height: 1.2),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (meeting['description'] != null && meeting['description'].toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(meeting['description'], style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.8), borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Text('${_formatDate(scheduledTime)} • ${_formatTime(scheduledTime)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFFE5E7EB))),
                    child: Text('${meeting['duration'] ?? 60}m', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
                  ),
                  const Spacer(),
                  if (expiryTime != null)
                    Text('Exp: ${_formatTime(expiryTime)}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: accentColor)),
                ],
              ),
            ),
            if (hasJoined)
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF16A34A)),
                    const SizedBox(width: 6),
                    const Expanded(child: Text('You joined', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF166534)))),
                    if (studentJoinTime != null)
                      Text(DateFormat('hh:mm a').format(studentJoinTime), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF16A34A))),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            if (displayAsActive)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _joinMeeting(meeting),
                  icon: Icon(buttonIcon, size: 18),
                  label: Text(buttonText, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: buttonBgColor,
                    foregroundColor: buttonColor,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                    shadowColor: buttonBgColor.withOpacity(0.4),
                  ),
                ),
              ),
            if (!displayAsActive && isUpcoming)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: null,
                  icon: Icon(buttonIcon, size: 18),
                  label: Text(buttonText, style: const TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: buttonColor,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: BorderSide(color: accentColor.withOpacity(0.3)),
                    backgroundColor: buttonBgColor,
                  ),
                ),
              ),
            if (!displayAsActive && isExpired)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: null,
                  icon: Icon(buttonIcon, size: 18),
                  label: Text(buttonText, style: const TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: buttonColor,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: BorderSide(color: accentColor.withOpacity(0.3)),
                    backgroundColor: buttonBgColor,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // =============================================
  // FOOTER
  // =============================================
  Widget _buildFooter() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: const Center(
        child: Text(
          'Developed By Devlk',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalMeetings = _activeMeetings.length + _upcomingMeetings.length + _expiredMeetings.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
          : Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _fetchMeetings,
                    color: const Color(0xFF2563EB),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),
                          if (totalMeetings > 0) ...[
                            _buildStatsRow(),
                            const SizedBox(height: 20),
                          ],
                          if (_activeMeetings.isNotEmpty) ...[
                            _buildSectionHeader('🟢 Live Now', _activeMeetings.length, const Color(0xFF10B981)),
                            const SizedBox(height: 8),
                            ..._activeMeetings.map((m) => _buildMeetingCard(m)),
                          ],
                          if (_upcomingMeetings.isNotEmpty) ...[
                            _buildSectionHeader('🟡 Upcoming', _upcomingMeetings.length, const Color(0xFFF59E0B)),
                            const SizedBox(height: 8),
                            ..._upcomingMeetings.map((m) => _buildMeetingCard(m)),
                          ],
                          if (_expiredMeetings.isNotEmpty) ...[
                            _buildSectionHeader('🔴 Past Classes', _expiredMeetings.length, const Color(0xFFEF4444)),
                            const SizedBox(height: 8),
                            ..._expiredMeetings.map((m) => _buildMeetingCard(m)),
                          ],
                          if (totalMeetings == 0)
                            Container(
                              margin: const EdgeInsets.only(top: 20),
                              padding: const EdgeInsets.all(40),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFFE5E7EB)),
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.video_call_rounded, size: 40, color: Color(0xFF94A3B8)),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text('No Meetings Yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                  const SizedBox(height: 6),
                                  const Text('Your teacher hasn\'t scheduled\nany classes yet', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8), height: 1.5)),
                                ],
                              ),
                            ),
                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
                  ),
                ),
                _buildFooter(),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Container(width: 3, height: 20, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 10),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Text('$count', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
          ),
        ],
      ),
    );
  }
}