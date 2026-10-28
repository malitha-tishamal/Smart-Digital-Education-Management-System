import '../../core/app_config.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../core/app_colors.dart';
import '../auth/login_screen.dart';
import 'student_drawer.dart';
import 'user_class_detail_screen.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isLoading = true;
  String _studentName = 'Student';
  String _profileImageUrl = '';
  String _studentStream = '';
  List<String> _studentSubjects = [];
  String _academicYear = '2024';
  List<Map<String, dynamic>> _enrollments = [];

  DateTime get _nowInSriLanka {
    return DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
  }

  String get _defaultProfileImageUrl => AppConfig.defaultProfileImageUrl;

  @override
  void initState() {
    super.initState();
    _loadStudentData();
  }

  Future<void> _loadStudentData() async {
    setState(() => _isLoading = true);
    final user = _auth.currentUser;
    if (user == null) { _goToLogin(); return; }
    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) { _goToLogin(); return; }
      final data = doc.data() as Map<String, dynamic>;
      _studentName = data['name'] ?? 'Student';
      _profileImageUrl = data['profileImageUrl'] ?? _defaultProfileImageUrl;
      _studentStream = data['stream'] ?? '';
      _studentSubjects = List<String>.from(data['subjects'] ?? []);
      _academicYear = data['alYear'] ?? '2024';
      await _fetchEnrollments();
    } catch (e) {
      print('Error loading student data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchEnrollments() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      final enrollmentsSnapshot = await _firestore.collection('enrollments').where('studentId', isEqualTo: user.uid).get();
      List<Map<String, dynamic>> enrollments = [];
      for (var enrollmentDoc in enrollmentsSnapshot.docs) {
        final enrollmentData = enrollmentDoc.data() as Map<String, dynamic>;
        final classId = enrollmentData['classId'] as String?;
        if (classId != null) {
          final teacherDoc = await _firestore.collection('users').doc(classId).get();
          if (teacherDoc.exists) {
            final teacherData = teacherDoc.data() as Map<String, dynamic>;
            final liveCount = await _getLiveMeetingCount(classId, user.uid);
            final upcomingCount = await _getUpcomingMeetingCount(classId, user.uid);
            enrollments.add({
              'enrollmentId': enrollmentDoc.id,
              'classId': classId,
              'status': enrollmentData['status'] ?? 'inactive',
              'paymentStatus': enrollmentData['paymentStatus'] ?? 'pending',
              'trialStart': (enrollmentData['trialStart'] as Timestamp?)?.toDate(),
              'trialEnd': (enrollmentData['trialEnd'] as Timestamp?)?.toDate(),
              'expiryDate': (enrollmentData['expiryDate'] as Timestamp?)?.toDate(),
              'freeAccess': enrollmentData['freeAccess'] ?? false,
              'teacherName': teacherData['name'] ?? 'Teacher',
              'teacherEmail': teacherData['email'] ?? '',
              'teacherStream': teacherData['stream'] ?? '',
              'teacherSubjects': List<String>.from(teacherData['subjects'] ?? []),
              'teacherProfileImageUrl': teacherData['profileImageUrl'] ?? _defaultProfileImageUrl,
              'paymentApproved': enrollmentData['paymentApproved'] ?? false,
              'studentName': _studentName,
              'liveCount': liveCount,
              'upcomingCount': upcomingCount,
            });
          }
        }
      }
      _enrollments = enrollments;
      setState(() {});
    } catch (e) {
      print('Error fetching enrollments: $e');
    }
  }

  Future<int> _getLiveMeetingCount(String teacherId, String studentId) async {
    try {
      final now = _nowInSriLanka;
      final meetingsSnapshot = await _firestore.collection('zoomMeetings').where('teacherId', isEqualTo: teacherId).get();
      int count = 0;
      for (var doc in meetingsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final scheduledTime = (data['scheduledTime'] as Timestamp?)?.toDate();
        final expiryTime = (data['expiryTime'] as Timestamp?)?.toDate();
        final duration = data['duration'] ?? 60;
        final status = data['status'] ?? 'upcoming';
        final students = List<String>.from(data['students'] ?? []);
        if (!students.contains(studentId)) continue;
        DateTime? endTime;
        if (scheduledTime != null) endTime = scheduledTime.add(Duration(minutes: duration));
        final isActive = status == 'active';
        final isTimeStarted = scheduledTime != null && now.isAfter(scheduledTime);
        final isTimeEnded = endTime != null && now.isAfter(endTime);
        final isExpired = (expiryTime != null && now.isAfter(expiryTime)) || status == 'expired' || status == 'disabled';
        final shouldBeLive = isTimeStarted && !isTimeEnded && !isExpired;
        if (isActive || (shouldBeLive && status == 'approved')) count++;
      }
      return count;
    } catch (e) { return 0; }
  }

  Future<int> _getUpcomingMeetingCount(String teacherId, String studentId) async {
    try {
      final now = _nowInSriLanka;
      final meetingsSnapshot = await _firestore.collection('zoomMeetings').where('teacherId', isEqualTo: teacherId).get();
      int count = 0;
      for (var doc in meetingsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final scheduledTime = (data['scheduledTime'] as Timestamp?)?.toDate();
        final status = data['status'] ?? 'upcoming';
        final students = List<String>.from(data['students'] ?? []);
        if (!students.contains(studentId)) continue;
        if ((status == 'approved' || status == 'upcoming') && scheduledTime != null && now.isBefore(scheduledTime)) count++;
      }
      return count;
    } catch (e) { return 0; }
  }

  bool _canAccessClass(Map<String, dynamic> enrollment) {
    final now = _nowInSriLanka;
    if (enrollment['status'] != 'active') return false;
    if (enrollment['freeAccess'] == true) return true;
    final trialEnd = enrollment['trialEnd'] as DateTime?;
    if (trialEnd != null && now.isBefore(trialEnd)) return true;
    final paymentApproved = enrollment['paymentApproved'] ?? false;
    final expiryDate = enrollment['expiryDate'] as DateTime?;
    if (paymentApproved && expiryDate != null && now.isBefore(expiryDate)) return true;
    return false;
  }

  String _getAccessStatus(Map<String, dynamic> enrollment) {
    final now = _nowInSriLanka;
    if (enrollment['freeAccess'] == true) return 'Free';
    final trialEnd = enrollment['trialEnd'] as DateTime?;
    if (trialEnd != null && now.isBefore(trialEnd)) return '${trialEnd.difference(now).inDays}d trial';
    final paymentApproved = enrollment['paymentApproved'] ?? false;
    final expiryDate = enrollment['expiryDate'] as DateTime?;
    if (paymentApproved && expiryDate != null && now.isBefore(expiryDate)) return '${expiryDate.difference(now).inDays}d left';
    if (trialEnd != null && now.isAfter(trialEnd) && !paymentApproved) return 'Locked';
    return 'Expired';
  }

  Color _getAccessStatusColor(Map<String, dynamic> enrollment) {
    final now = _nowInSriLanka;
    if (enrollment['freeAccess'] == true) return const Color(0xFF10B981);
    final trialEnd = enrollment['trialEnd'] as DateTime?;
    if (trialEnd != null && now.isBefore(trialEnd)) return const Color(0xFFF59E0B);
    final paymentApproved = enrollment['paymentApproved'] ?? false;
    final expiryDate = enrollment['expiryDate'] as DateTime?;
    if (paymentApproved && expiryDate != null && now.isBefore(expiryDate)) return const Color(0xFF10B981);
    return const Color(0xFFEF4444);
  }

  void _goToLogin() {
    if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage()));
  }

  Future<void> _logout(BuildContext context) async {
    await _auth.signOut();
    if (context.mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage()));
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
            Text(_studentName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 4),
            Text('AL $_academicYear • Student', style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ]),
          const Spacer(),
          CircleAvatar(radius: 40, backgroundImage: NetworkImage(_profileImageUrl), backgroundColor: Colors.grey.shade200, onBackgroundImageError: (_, __) {}, child: _profileImageUrl == _defaultProfileImageUrl ? const Icon(Icons.person, size: 40, color: Colors.white) : null),
        ]),
        const SizedBox(height: 20),
        const Text('My Classes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
      ]),
    );
  }

  Widget _buildDrawer() {
    return StudentDrawer(userName: _studentName, userEmail: _auth.currentUser?.email ?? 'student@example.com', profileImageUrl: _profileImageUrl, onLogout: () => _logout(context));
  }

  // =============================================
  // 🎨 VIBRANT MODERN CLASS CARD
  // =============================================
  Widget _buildClassCard(Map<String, dynamic> enrollment) {
    final canAccess = _canAccessClass(enrollment);
    final accessStatus = _getAccessStatus(enrollment);
    final accessColor = _getAccessStatusColor(enrollment);
    final teacherName = enrollment['teacherName'] ?? 'Teacher';
    final teacherStream = enrollment['teacherStream'] ?? '';
    final teacherSubjects = enrollment['teacherSubjects'] as List<String>? ?? [];
    final teacherImageUrl = enrollment['teacherProfileImageUrl'] ?? '';
    final liveCount = enrollment['liveCount'] ?? 0;
    final upcomingCount = enrollment['upcomingCount'] ?? 0;

    // Vibrant card colors
    Color cardBg;
    Color borderColor;
    Color accentBg;
    List<Color> statusGradient;
    Color liveDotColor;
    Color topStripColor;
    
    if (liveCount > 0 && canAccess) {
      // Live - Vibrant Red/Pink
      cardBg = const Color(0xFFFFF5F5);
      borderColor = const Color(0xFFFECACA);
      accentBg = const Color(0xFFFEF2F2);
      statusGradient = [const Color(0xFFEF4444), const Color(0xFFDC2626)];
      liveDotColor = const Color(0xFFEF4444);
      topStripColor = const Color(0xFFEF4444);
    } else if (canAccess && accessColor == const Color(0xFF10B981)) {
      // Active/Paid - Vibrant Green
      cardBg = const Color(0xFFF0FDF4);
      borderColor = const Color(0xFF86EFAC);
      accentBg = const Color(0xFFDCFCE7);
      statusGradient = [const Color(0xFF10B981), const Color(0xFF059669)];
      liveDotColor = const Color(0xFF10B981);
      topStripColor = const Color(0xFF10B981);
    } else if (canAccess && accessColor == const Color(0xFFF59E0B)) {
      // Trial - Vibrant Amber
      cardBg = const Color(0xFFFFFBEB);
      borderColor = const Color(0xFFFDE68A);
      accentBg = const Color(0xFFFEF3C7);
      statusGradient = [const Color(0xFFF59E0B), const Color(0xFFD97706)];
      liveDotColor = const Color(0xFFF59E0B);
      topStripColor = const Color(0xFFF59E0B);
    } else {
      // Locked/Expired - Vibrant Red
      cardBg = const Color(0xFFFEF2F2);
      borderColor = const Color(0xFFFECACA);
      accentBg = const Color(0xFFFEE2E2);
      statusGradient = [const Color(0xFFEF4444), const Color(0xFFDC2626)];
      liveDotColor = const Color(0xFFEF4444);
      topStripColor = const Color(0xFFEF4444);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: topStripColor.withOpacity(0.15), blurRadius: 15, offset: const Offset(0, 4)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          children: [
            // Top accent strip
            Container(
              height: 4,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [topStripColor, topStripColor.withOpacity(0.5)]),
              ),
            ),
            
            // Live pulse banner
            if (liveCount > 0 && canAccess)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                color: accentBg,
                child: Row(
                  children: [
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                        color: liveDotColor,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: liveDotColor.withOpacity(0.6), blurRadius: 6, spreadRadius: 1)],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$liveCount class live now',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: topStripColor),
                    ),
                    const Spacer(),
                    Icon(Icons.arrow_forward_ios, size: 10, color: topStripColor),
                  ],
                ),
              ),
            
            // Main content
            Container(
              color: cardBg,
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Teacher row
                  Row(
                    children: [
                      // Avatar
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: topStripColor.withOpacity(0.3), width: 2),
                          boxShadow: [BoxShadow(color: topStripColor.withOpacity(0.2), blurRadius: 8)],
                        ),
                        child: CircleAvatar(
                          radius: 24,
                          backgroundImage: teacherImageUrl.isNotEmpty ? NetworkImage(teacherImageUrl) : null,
                          backgroundColor: topStripColor.withOpacity(0.1),
                          child: teacherImageUrl.isEmpty
                              ? Text(teacherName.isNotEmpty ? teacherName[0].toUpperCase() : 'T',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: topStripColor))
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(teacherName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                const Icon(Icons.school_rounded, size: 12, color: Color(0xFF6366F1)),
                                const SizedBox(width: 4),
                                Flexible(child: Text(teacherStream, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF6366F1)), overflow: TextOverflow.ellipsis)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Status badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: statusGradient),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: topStripColor.withOpacity(0.3), blurRadius: 4)],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(canAccess ? Icons.lock_open : Icons.lock, size: 10, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(accessStatus, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  // Subjects
                  if (teacherSubjects.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(spacing: 5, runSpacing: 5, children: teacherSubjects.take(3).map((subject) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(subject, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Color(0xFF475569))),
                      );
                    }).toList()),
                    if (teacherSubjects.length > 3)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('+${teacherSubjects.length - 3} more', style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
                      ),
                  ],
                  
                  // Meeting counts
                  if (canAccess && (liveCount > 0 || upcomingCount > 0))
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Row(
                        children: [
                          if (liveCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(6)),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Container(width: 5, height: 5, decoration: BoxDecoration(color: const Color(0xFFEF4444), shape: BoxShape.circle)),
                                const SizedBox(width: 4),
                                Text('$liveCount Live', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFFEF4444))),
                              ]),
                            ),
                          if (liveCount > 0 && upcomingCount > 0) const SizedBox(width: 8),
                          if (upcomingCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(6)),
                              child: Text('$upcomingCount Upcoming', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF6366F1))),
                            ),
                        ],
                      ),
                    ),
                  
                  const SizedBox(height: 12),
                  
                  // Visit Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: canAccess
                          ? () => Navigator.push(context, MaterialPageRoute(builder: (context) => UserClassDetailScreen(enrollment: enrollment)))
                          : () => _showPaymentRequiredDialog(enrollment),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: liveCount > 0 && canAccess ? const Color(0xFFEF4444) : (canAccess ? const Color(0xFF6366F1) : const Color(0xFF9CA3AF)),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 1,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(canAccess ? Icons.arrow_forward_rounded : Icons.lock_rounded, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            liveCount > 0 && canAccess ? 'Join Live Class' : (canAccess ? 'Visit Class' : 'Locked'),
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPaymentRequiredDialog(Map<String, dynamic> enrollment) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [Icon(Icons.lock, color: Color(0xFFEF4444)), SizedBox(width: 8), Text('Access Locked')]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Your free trial has expired. Please make a payment to continue.', style: TextStyle(fontSize: 14)),
          const SizedBox(height: 12),
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8)), child: const Row(children: [Icon(Icons.warning, size: 14, color: Color(0xFFEF4444)), SizedBox(width: 8), Expanded(child: Text('Contact teacher to make payment.', style: TextStyle(fontSize: 11, color: Color(0xFF991B1B))))])),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ElevatedButton(onPressed: () { Navigator.pop(ctx); }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text('OK')),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: const Color(0xFFF1F5F9), shape: BoxShape.circle), child: const Icon(Icons.class_rounded, size: 44, color: Color(0xFF94A3B8))),
        const SizedBox(height: 16),
        const Text('No classes enrolled', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
        const SizedBox(height: 6),
        const Text('Contact your admin to enroll.', style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
      ]),
    );
  }

  Widget _buildFooter() {
    return Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 10), child: const Center(child: Text('Developed By Devlk', style: TextStyle(fontSize: 11, color: Colors.black54))));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: _buildDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
          : Column(children: [
              _buildHeader(),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadStudentData,
                  color: const Color(0xFF6366F1),
                  child: _enrollments.isEmpty
                      ? ListView(children: [_buildEmptyState()])
                      : ListView.builder(padding: const EdgeInsets.all(14), itemCount: _enrollments.length, itemBuilder: (context, index) => _buildClassCard(_enrollments[index])),
                ),
              ),
              _buildFooter(),
            ]),
    );
  }
}