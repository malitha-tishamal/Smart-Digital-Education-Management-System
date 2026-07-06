import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../core/app_colors.dart';
import '../../auth/login_screen.dart';
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

  // Sri Lanka time
  DateTime get _nowInSriLanka {
    return DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
  }

  static const String _defaultProfileImageUrl =
      'https://res.cloudinary.com/dqeptzlsb/image/upload/v1782734371/default_il19eg.png';

  @override
  void initState() {
    super.initState();
    _loadStudentData();
  }

  Future<void> _loadStudentData() async {
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

      final enrollmentsSnapshot = await _firestore
          .collection('enrollments')
          .where('studentId', isEqualTo: user.uid)
          .get();

      List<Map<String, dynamic>> enrollments = [];

      for (var enrollmentDoc in enrollmentsSnapshot.docs) {
        final enrollmentData = enrollmentDoc.data() as Map<String, dynamic>;
        final classId = enrollmentData['classId'] as String?;
        
        if (classId != null) {
          final teacherDoc = await _firestore.collection('users').doc(classId).get();
          if (teacherDoc.exists) {
            final teacherData = teacherDoc.data() as Map<String, dynamic>;
            
            // Check for live meetings
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
              'assignedDate': (enrollmentData['assignedDate'] as Timestamp?)?.toDate(),
              'teacherName': teacherData['name'] ?? 'Teacher',
              'teacherEmail': teacherData['email'] ?? '',
              'teacherStream': teacherData['stream'] ?? '',
              'teacherSubjects': List<String>.from(teacherData['subjects'] ?? []),
              'teacherProfileImageUrl': teacherData['profileImageUrl'] ?? _defaultProfileImageUrl,
              'paymentApproved': enrollmentData['paymentApproved'] ?? false,
              'currentMonth': enrollmentData['currentMonth'] ?? '',
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
      final meetingsSnapshot = await _firestore
          .collection('zoomMeetings')
          .where('teacherId', isEqualTo: teacherId)
          .get();

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
        if (scheduledTime != null) {
          endTime = scheduledTime.add(Duration(minutes: duration));
        }
        
        final isActive = status == 'active';
        final isTimeStarted = scheduledTime != null && now.isAfter(scheduledTime);
        final isTimeEnded = endTime != null && now.isAfter(endTime);
        final isExpired = expiryTime != null && now.isAfter(expiryTime) || status == 'expired' || status == 'disabled';
        final shouldBeLive = isTimeStarted && !isTimeEnded && !isExpired;
        
        if (isActive || (shouldBeLive && status == 'approved')) {
          count++;
        }
      }
      return count;
    } catch (e) {
      return 0;
    }
  }

  Future<int> _getUpcomingMeetingCount(String teacherId, String studentId) async {
    try {
      final now = _nowInSriLanka;
      final meetingsSnapshot = await _firestore
          .collection('zoomMeetings')
          .where('teacherId', isEqualTo: teacherId)
          .get();

      int count = 0;
      for (var doc in meetingsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final scheduledTime = (data['scheduledTime'] as Timestamp?)?.toDate();
        final status = data['status'] ?? 'upcoming';
        final students = List<String>.from(data['students'] ?? []);
        
        if (!students.contains(studentId)) continue;
        
        final isUpcoming = status == 'approved' || status == 'upcoming';
        
        if (isUpcoming && scheduledTime != null && now.isBefore(scheduledTime)) {
          count++;
        }
      }
      return count;
    } catch (e) {
      return 0;
    }
  }

  bool _canAccessClass(Map<String, dynamic> enrollment) {
    final now = _nowInSriLanka;
    final trialEnd = enrollment['trialEnd'] as DateTime?;
    final expiryDate = enrollment['expiryDate'] as DateTime?;
    final paymentApproved = enrollment['paymentApproved'] ?? false;
    final status = enrollment['status'] ?? 'inactive';

    if (status != 'active') return false;
    if (enrollment['freeAccess'] == true) return true;
    if (trialEnd != null && now.isBefore(trialEnd)) return true;
    if (paymentApproved && expiryDate != null && now.isBefore(expiryDate)) return true;

    return false;
  }

  String _getAccessStatus(Map<String, dynamic> enrollment) {
    final now = _nowInSriLanka;
    final trialEnd = enrollment['trialEnd'] as DateTime?;
    final expiryDate = enrollment['expiryDate'] as DateTime?;
    final paymentApproved = enrollment['paymentApproved'] ?? false;

    if (enrollment['freeAccess'] == true) return 'Free Access';
    
    if (trialEnd != null) {
      if (now.isBefore(trialEnd)) {
        final daysLeft = trialEnd.difference(now).inDays;
        return 'Trial: $daysLeft days';
      }
    }

    if (paymentApproved && expiryDate != null) {
      if (now.isBefore(expiryDate)) {
        final daysLeft = expiryDate.difference(now).inDays;
        return 'Paid: $daysLeft days';
      }
    }

    if (trialEnd != null && now.isAfter(trialEnd) && !paymentApproved) {
      return 'Payment Required';
    }

    return 'Expired';
  }

  Color _getAccessStatusColor(Map<String, dynamic> enrollment) {
    final now = _nowInSriLanka;
    final trialEnd = enrollment['trialEnd'] as DateTime?;
    final expiryDate = enrollment['expiryDate'] as DateTime?;
    final paymentApproved = enrollment['paymentApproved'] ?? false;

    if (enrollment['freeAccess'] == true) return const Color(0xFF10B981);
    if (trialEnd != null && now.isBefore(trialEnd)) return const Color(0xFFF59E0B);
    if (paymentApproved && expiryDate != null && now.isBefore(expiryDate)) return const Color(0xFF10B981);

    return const Color(0xFFEF4444);
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
          BoxShadow(color: Color(0x10000000), blurRadius: 15, offset: Offset(0, 5)),
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
                  Text(_studentName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text('AL $_academicYear • Student', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                ],
              ),
              const Spacer(),
              CircleAvatar(
                radius: 40,
                backgroundImage: NetworkImage(_profileImageUrl),
                backgroundColor: Colors.grey.shade200,
                onBackgroundImageError: (_, __) {},
                child: _profileImageUrl == _defaultProfileImageUrl ? const Icon(Icons.person, size: 40, color: Colors.white) : null,
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text('My Classes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
        ],
      ),
    );
  }

  // ---- Drawer ----
  Widget _buildDrawer() {
    return StudentDrawer(
      userName: _studentName,
      userEmail: _auth.currentUser?.email ?? 'student@example.com',
      profileImageUrl: _profileImageUrl,
      onLogout: () => _logout(context),
    );
  }

  // =============================================
  // 🎨 MODERN CLASS CARD
  // =============================================
  Widget _buildClassCard(Map<String, dynamic> enrollment) {
    final canAccess = _canAccessClass(enrollment);
    final accessStatus = _getAccessStatus(enrollment);
    final accessColor = _getAccessStatusColor(enrollment);
    final teacherName = enrollment['teacherName'] ?? 'Teacher';
    final teacherEmail = enrollment['teacherEmail'] ?? '';
    final teacherStream = enrollment['teacherStream'] ?? '';
    final teacherSubjects = enrollment['teacherSubjects'] as List<String>? ?? [];
    final teacherImageUrl = enrollment['teacherProfileImageUrl'] ?? '';
    final liveCount = enrollment['liveCount'] ?? 0;
    final upcomingCount = enrollment['upcomingCount'] ?? 0;

    Color cardBg;
    Color borderColor;
    List<Color> statusGradient;
    
    if (canAccess && accessColor == const Color(0xFF10B981)) {
      cardBg = const Color(0xFFF0FDF4);
      borderColor = const Color(0xFFBBF7D0);
      statusGradient = [const Color(0xFF10B981), const Color(0xFF059669)];
    } else if (canAccess && accessColor == const Color(0xFFF59E0B)) {
      cardBg = const Color(0xFFFFFBEB);
      borderColor = const Color(0xFFFDE68A);
      statusGradient = [const Color(0xFFF59E0B), const Color(0xFFD97706)];
    } else {
      cardBg = const Color(0xFFFEF2F2);
      borderColor = const Color(0xFFFECACA);
      statusGradient = [const Color(0xFFEF4444), const Color(0xFFDC2626)];
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cardBg, cardBg.withOpacity(0.5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: liveCount > 0 ? const Color(0xFF10B981) : borderColor, width: liveCount > 0 ? 2 : 1),
        boxShadow: [
          BoxShadow(color: (liveCount > 0 ? const Color(0xFF10B981) : accessColor).withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Live indicator
            if (liveCount > 0 && canAccess)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8, height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$liveCount Live Now',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFDC2626)),
                    ),
                  ],
                ),
              ),
            
            // Top Row: Avatar + Info + Status
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: accessColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: CircleAvatar(
                    radius: 30,
                    backgroundImage: teacherImageUrl.isNotEmpty ? NetworkImage(teacherImageUrl) : null,
                    backgroundColor: accessColor.withOpacity(0.2),
                    child: teacherImageUrl.isEmpty
                        ? Text(teacherName.isNotEmpty ? teacherName[0].toUpperCase() : 'T',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: accessColor))
                        : null,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(teacherName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                      const SizedBox(height: 2),
                      Text(teacherEmail, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)), overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: statusGradient),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: accessColor.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2))],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(canAccess ? Icons.lock_open : Icons.lock, size: 12, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(accessStatus, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 14),
            
            // Stream Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.15)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.school_rounded, size: 13, color: Color(0xFF6366F1)),
                  const SizedBox(width: 5),
                  Text('Stream: $teacherStream', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6366F1))),
                ],
              ),
            ),
            
            const SizedBox(height: 10),
            
            // Subjects
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: teacherSubjects.map((subject) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(subject, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Color(0xFF475569))),
                );
              }).toList(),
            ),
            
            // Meeting counts
            if (canAccess && (liveCount > 0 || upcomingCount > 0))
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  children: [
                    if (liveCount > 0) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6, height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFFEF4444),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text('$liveCount Live', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFFDC2626))),
                          ],
                        ),
                      ),
                    ],
                    if (liveCount > 0 && upcomingCount > 0) const SizedBox(width: 8),
                    if (upcomingCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFC7D2FE)),
                        ),
                        child: Text('$upcomingCount Upcoming', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF4F46E5))),
                      ),
                  ],
                ),
              ),
            
            // Trial/Payment Info
            if (enrollment['trialEnd'] != null)
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_rounded, size: 15, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Free trial until ${DateFormat('MMM dd, yyyy').format(enrollment['trialEnd'])}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF92400E)),
                      ),
                    ),
                  ],
                ),
              ),
            
            if (enrollment['expiryDate'] != null && enrollment['paymentApproved'] == true)
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_rounded, size: 15, color: Color(0xFF10B981)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Paid until ${DateFormat('MMM dd, yyyy').format(enrollment['expiryDate'])}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF065F46)),
                      ),
                    ),
                  ],
                ),
              ),
            
            const SizedBox(height: 14),
            
            // Visit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: canAccess
                    ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => UserClassDetailScreen(enrollment: enrollment),
                          ),
                        );
                      }
                    : () => _showPaymentRequiredDialog(enrollment),
                icon: Icon(canAccess ? Icons.arrow_forward_rounded : Icons.lock_rounded, size: 18),
                label: Text(
                  canAccess && liveCount > 0 ? 'Join Live Class' : (canAccess ? 'Visit Class' : 'Payment Required'),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: canAccess && liveCount > 0 ? const Color(0xFFEF4444) : (canAccess ? const Color(0xFF6366F1) : const Color(0xFFEF4444)),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                  shadowColor: (canAccess ? const Color(0xFF6366F1) : const Color(0xFFEF4444)).withOpacity(0.4),
                ),
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
        title: const Row(
          children: [
            Icon(Icons.lock, color: Color(0xFFEF4444)),
            SizedBox(width: 8),
            Text('Access Locked'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your free trial has expired. Please make a payment to continue accessing this class.',
              style: TextStyle(fontSize: 14, color: Color(0xFF374151)),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning, size: 16, color: Color(0xFFEF4444)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Contact your teacher or admin to make payment.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF991B1B)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please contact your teacher for payment'), backgroundColor: Color(0xFFF59E0B)),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Contact Teacher'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.class_rounded, size: 56, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 20),
          const Text('No classes enrolled', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
          const SizedBox(height: 8),
          const Text('You are not enrolled in any class yet.\nPlease contact your admin.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8), height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: const Center(
        child: Text('Developed By Devlk', style: TextStyle(fontSize: 12, color: Colors.black54)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF9FAFB),
      drawer: _buildDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
          : Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadStudentData,
                    color: const Color(0xFF6366F1),
                    child: _enrollments.isEmpty
                        ? ListView(children: [_buildEmptyState()])
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _enrollments.length,
                            itemBuilder: (context, index) {
                              return _buildClassCard(_enrollments[index]);
                            },
                          ),
                  ),
                ),
                _buildFooter(),
              ],
            ),
    );
  }
}