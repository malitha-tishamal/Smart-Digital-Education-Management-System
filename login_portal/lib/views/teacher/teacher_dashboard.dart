import '../../core/app_config.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/app_colors.dart';
import '../auth/login_screen.dart';
import 'teacher_drawer.dart';

class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({super.key});

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isLoading = true;
  String _teacherName = 'Teacher';
  String _teacherEmail = '';
  String _profileImageUrl = '';
  String _teacherStream = '';
  List<String> _teacherSubjects = [];

  // Statistics
  int _totalStudents = 0;
  int _activeEnrollments = 0;
  int _pendingEnrollments = 0;
  int _paidStudents = 0;
  int _pendingPaymentStudents = 0;
  
  // Current Month Payment Statistics
  int _currentMonthPaidStudents = 0;
  int _currentMonthPendingPayment = 0;
  double _currentMonthPaymentTotal = 0.0;
  String _currentMonth = '';
  
  // Categorized students by academic year
  Map<String, List<Map<String, dynamic>>> _studentsByYear = {};
  List<String> _academicYears = [];
  
  List<Map<String, dynamic>> _recentEnrolledStudents = [];

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

      // Set current month
      final now = DateTime.now();
      _currentMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';

      await _fetchEnrollments();
    } catch (e) {
      print('Error loading teacher data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchEnrollments() async {
    try {
      // Get all enrollments
      final enrollmentsSnapshot = await _firestore.collection('enrollments').get();
      
      List<Map<String, dynamic>> enrichedEnrollments = [];
      
      for (var doc in enrollmentsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final studentId = data['studentId'] ?? '';
        if (studentId.isEmpty) continue;
        
        // Get student details
        final studentDoc = await _firestore.collection('users').doc(studentId).get();
        if (!studentDoc.exists) continue;
        
        final studentData = studentDoc.data() as Map<String, dynamic>;
        final studentSubjects = List<String>.from(studentData['subjects'] ?? []);
        
        // Check if student matches teacher's subjects or stream
        bool hasMatchingSubject = false;
        for (var subject in studentSubjects) {
          if (_teacherSubjects.contains(subject)) {
            hasMatchingSubject = true;
            break;
          }
        }
        
        final studentStream = studentData['stream'] ?? '';
        bool hasMatchingStream = _teacherStream.isNotEmpty && 
                                 studentStream == _teacherStream;
        
        if (hasMatchingSubject || hasMatchingStream) {
          final enrollmentData = {
            'id': doc.id,
            'studentId': studentId,
            'studentName': studentData['name'] ?? 'Unknown',
            'studentEmail': studentData['email'] ?? 'No email',
            'studentProfileImageUrl': studentData['profileImageUrl'] ?? _defaultProfileImageUrl,
            'studentCustomId': studentData['studentId'] ?? '',
            'studentStream': studentStream,
            'studentSubjects': studentSubjects,
            'academicYear': studentData['alYear'] ?? 'N/A',
            'lastLoginAt': (studentData['lastLoginAt'] as Timestamp?)?.toDate(),
            'status': data['status'] ?? 'pending',
            'paymentStatus': data['paymentStatus'] ?? 'unpaid',
            'paymentApproved': data['paymentApproved'] ?? false,
            'assignedDate': (data['assignedDate'] as Timestamp?)?.toDate(),
            'expiryDate': (data['expiryDate'] as Timestamp?)?.toDate(),
            'lastPaymentDate': (data['lastPaymentDate'] as Timestamp?)?.toDate(),
            'transactionId': data['transactionId'] ?? '',
            'paymentMonth': data['paymentMonth'] ?? '',
            'currentMonth': data['currentMonth'] ?? '',
          };
          enrichedEnrollments.add(enrollmentData);
        }
      }

      // Calculate stats
      _totalStudents = enrichedEnrollments.length;
      _activeEnrollments = enrichedEnrollments.where((e) => e['status'] == 'active').length;
      _pendingEnrollments = enrichedEnrollments.where((e) => e['status'] == 'pending').length;
      _paidStudents = enrichedEnrollments.where((e) => e['paymentStatus'] == 'paid').length;
      _pendingPaymentStudents = enrichedEnrollments.where((e) => e['paymentStatus'] != 'paid').length;

      // Calculate current month payment statistics
      _currentMonthPaidStudents = enrichedEnrollments.where((e) => 
        e['paymentStatus'] == 'paid' && 
        e['paymentMonth'] == _currentMonth
      ).length;
      
      _currentMonthPendingPayment = enrichedEnrollments.where((e) => 
        e['paymentStatus'] != 'paid' && 
        e['paymentMonth'] == _currentMonth
      ).length;
      
      final double paymentAmount = 2500.0;
      _currentMonthPaymentTotal = _currentMonthPaidStudents * paymentAmount;

      // Group students by academic year
      _studentsByYear = {};
      for (var student in enrichedEnrollments) {
        final year = student['academicYear'] ?? 'N/A';
        if (!_studentsByYear.containsKey(year)) {
          _studentsByYear[year] = [];
        }
        _studentsByYear[year]!.add(student);
      }
      
      // Sort academic years descending
      _academicYears = _studentsByYear.keys.toList()..sort((a, b) => b.compareTo(a));

      // Get recent 10 students by lastLoginAt
      enrichedEnrollments.sort((a, b) {
        final aDate = a['lastLoginAt'] as DateTime?;
        final bDate = b['lastLoginAt'] as DateTime?;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });

      _recentEnrolledStudents = enrichedEnrollments.take(10).toList();

    } catch (e) {
      print('Error fetching enrollments: $e');
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
            'Teacher Dashboard',
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

  // ---- Enhanced Stats Card ----
  Widget _buildEnhancedStatCard({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
    required Color gradientColor,
    required String subtitle,
    String? extraInfo,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.15), gradientColor.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.darkText,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade500,
              ),
            ),
            if (extraInfo != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  extraInfo,
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.grey.shade400,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---- Compact Current Month Payment Box ----
  Widget _buildCurrentMonthPaymentBox() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF059669).withOpacity(0.1),
            const Color(0xFF059669).withOpacity(0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF059669).withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF059669).withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.payment_rounded, color: Color(0xFF059669), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This Month Payments',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Total: LKR ${_currentMonthPaymentTotal.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          _buildCompactStat(
            label: 'Paid',
            count: _currentMonthPaidStudents,
            color: const Color(0xFF059669),
          ),
          const SizedBox(width: 8),
          _buildCompactStat(
            label: 'Pending',
            count: _currentMonthPendingPayment,
            color: const Color(0xFFDC2626),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStat({
    required String label,
    required int count,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  // ---- Academic Year Category Box ----
  Widget _buildAcademicYearBox(String year, List<Map<String, dynamic>> students) {
    final activeCount = students.where((s) => s['status'] == 'active').length;
    final pendingCount = students.where((s) => s['status'] == 'pending').length;
    final paidCount = students.where((s) => s['paymentStatus'] == 'paid').length;
    final unpaidCount = students.where((s) => s['paymentStatus'] != 'paid').length;

    // Display only first 3 students by default
    final displayedStudents = students.take(3).toList();
    final hasMore = students.length > 3;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryPurple.withOpacity(0.05),
            AppColors.primaryPurple.withOpacity(0.01),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primaryPurple.withOpacity(0.15),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Year Header
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
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_today, color: AppColors.primaryPurple, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      'Academic Year $year',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkText,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryPurple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${students.length} Students',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryPurple,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Stats Row (Counters)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _buildMiniStat(label: 'Active', count: activeCount, color: const Color(0xFF059669), icon: Icons.check_circle),
                const SizedBox(width: 12),
                _buildMiniStat(label: 'Pending', count: pendingCount, color: const Color(0xFFF59E0B), icon: Icons.pending),
                const SizedBox(width: 12),
                _buildMiniStat(label: 'Paid', count: paidCount, color: const Color(0xFF2563EB), icon: Icons.payment),
                const SizedBox(width: 12),
                _buildMiniStat(label: 'Unpaid', count: unpaidCount, color: const Color(0xFFDC2626), icon: Icons.payment_outlined),
              ],
            ),
          ),
          
          // Student List (First 3 only)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: displayedStudents.map((student) {
                return _buildStudentTile(student);
              }).toList(),
            ),
          ),
          
          // See All Button (only if more than 3 students)
          if (hasMore)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Center(
                child: TextButton.icon(
                  onPressed: () => _showAllStudentsModal(year, students),
                  icon: const Icon(Icons.visibility, size: 18),
                  label: Text('See All ${students.length} Students'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryPurple,
                    backgroundColor: AppColors.primaryPurple.withOpacity(0.05),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // Modal to show all students for a year
  void _showAllStudentsModal(String year, List<Map<String, dynamic>> students) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                // Modal Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, color: AppColors.primaryPurple),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Academic Year $year - All Students',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryPurple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${students.length} Students',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryPurple,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                // Student List
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: students.length,
                    itemBuilder: (context, index) {
                      return _buildStudentTile(students[index]);
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ---- Mini Stat for Year Box ----
  Widget _buildMiniStat({
    required String label,
    required int count,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 10, color: color),
                const SizedBox(width: 2),
                Text(
                  label,
                  style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---- Student Tile ----
  Widget _buildStudentTile(Map<String, dynamic> student) {
    Color statusColor = student['status'] == 'active'
        ? const Color(0xFF059669)
        : const Color(0xFFF59E0B);
    
    Color paymentColor = student['paymentStatus'] == 'paid'
        ? const Color(0xFF059669)
        : const Color(0xFFDC2626);

    String lastLoginText = 'Never';
    if (student['lastLoginAt'] != null) {
      final now = DateTime.now();
      final diff = now.difference(student['lastLoginAt']);
      if (diff.inDays > 0) {
        lastLoginText = '${diff.inDays}d ago';
      } else if (diff.inHours > 0) {
        lastLoginText = '${diff.inHours}h ago';
      } else if (diff.inMinutes > 0) {
        lastLoginText = '${diff.inMinutes}m ago';
      } else {
        lastLoginText = 'Now';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundImage: NetworkImage(student['studentProfileImageUrl']),
            backgroundColor: Colors.grey.shade200,
            child: student['studentProfileImageUrl'] == _defaultProfileImageUrl
                ? const Icon(Icons.person, size: 22, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      student['studentName'],
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkText,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        student['status'],
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  student['studentEmail'],
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: paymentColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            student['paymentStatus'] == 'paid' ? Icons.payment : Icons.payment_outlined,
                            size: 10,
                            color: paymentColor,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            student['paymentStatus'] == 'paid' ? 'Paid' : 'Unpaid',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                              color: paymentColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 10, color: Colors.grey.shade500),
                        const SizedBox(width: 2),
                        Text(lastLoginText, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                      ],
                    ),
                    if (student['studentCustomId'].toString().isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.primaryPurple.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          student['studentCustomId'],
                          style: TextStyle(
                            fontSize: 8,
                            color: AppColors.primaryPurple,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---- Recent Student Card ----
  Widget _buildRecentStudentCard(Map<String, dynamic> student) {
    String lastLoginText = 'Never logged in';
    if (student['lastLoginAt'] != null) {
      final now = DateTime.now();
      final diff = now.difference(student['lastLoginAt']);
      if (diff.inDays > 0) {
        lastLoginText = '${diff.inDays}d ago';
      } else if (diff.inHours > 0) {
        lastLoginText = '${diff.inHours}h ago';
      } else if (diff.inMinutes > 0) {
        lastLoginText = '${diff.inMinutes}m ago';
      } else {
        lastLoginText = 'Just now';
      }
    }

    Color statusColor = student['status'] == 'active'
        ? const Color(0xFF059669)
        : const Color(0xFFF59E0B);

    Color paymentColor = student['paymentStatus'] == 'paid'
        ? const Color(0xFF059669)
        : const Color(0xFFDC2626);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade100, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundImage: NetworkImage(student['studentProfileImageUrl']),
              backgroundColor: Colors.grey.shade200,
              child: student['studentProfileImageUrl'] == _defaultProfileImageUrl
                  ? const Icon(Icons.person, size: 28, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        student['studentName'],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkText,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          student['status'],
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: paymentColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              student['paymentStatus'] == 'paid' ? Icons.payment : Icons.payment_outlined,
                              size: 12,
                              color: paymentColor,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              student['paymentStatus'] == 'paid' ? 'Paid' : 'Unpaid',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: paymentColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    student['studentEmail'],
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 12, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(lastLoginText, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                        ],
                      ),
                      const SizedBox(width: 10),
                      if (student['studentCustomId'].toString().isNotEmpty)
                        Row(
                          children: [
                            Icon(Icons.badge_outlined, size: 12, color: AppColors.primaryPurple),
                            const SizedBox(width: 4),
                            Text(
                              student['studentCustomId'],
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppColors.primaryPurple,
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(width: 10),
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(
                            student['academicYear'] ?? 'N/A',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (student['studentSubjects'] != null && (student['studentSubjects'] as List).isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 2,
                        children: (student['studentSubjects'] as List)
                            .where((subject) => _teacherSubjects.contains(subject))
                            .map((subject) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryPurple.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    subject,
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: AppColors.primaryPurple,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ))
                            .toList(),
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

  // ---- Teacher Info Header ----
  Widget _buildTeacherInfoHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryPurple.withOpacity(0.08),
            AppColors.primaryPurple.withOpacity(0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primaryPurple.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.school, color: AppColors.primaryPurple, size: 20),
              const SizedBox(width: 8),
              Text(
                'Your Teaching Areas',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.category, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 6),
                      Text(
                        _teacherStream.isNotEmpty ? _teacherStream : 'No stream assigned',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: _teacherStream.isNotEmpty ? AppColors.darkText : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.book, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _teacherSubjects.isNotEmpty ? _teacherSubjects.join(', ') : 'No subjects assigned',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: _teacherSubjects.isNotEmpty ? AppColors.darkText : Colors.grey.shade500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.lightBackground,
      drawer: _buildDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryPurple))
          : Column(
              children: [
                _buildHeader(),
                // Scrollable content area
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _fetchEnrollments,
                    color: AppColors.primaryPurple,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTeacherInfoHeader(),
                          const SizedBox(height: 16),
                          
                          // Stats cards - First Row
                          Row(
                            children: [
                              _buildEnhancedStatCard(
                                title: 'Total',
                                count: _totalStudents,
                                icon: Icons.people_alt_rounded,
                                color: const Color(0xFF2563EB),
                                gradientColor: const Color(0xFF2563EB),
                                subtitle: 'All enrolled',
                                extraInfo: 'Across ${_academicYears.length} years',
                              ),
                              const SizedBox(width: 10),
                              _buildEnhancedStatCard(
                                title: 'Active',
                                count: _activeEnrollments,
                                icon: Icons.check_circle_rounded,
                                color: const Color(0xFF059669),
                                gradientColor: const Color(0xFF059669),
                                subtitle: 'Currently active',
                              ),
                              const SizedBox(width: 10),
                              _buildEnhancedStatCard(
                                title: 'Pending',
                                count: _pendingEnrollments,
                                icon: Icons.pending_actions_rounded,
                                color: const Color(0xFFF59E0B),
                                gradientColor: const Color(0xFFF59E0B),
                                subtitle: 'Awaiting approval',
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          
                          // Stats cards - Second Row (Payment)
                          Row(
                            children: [
                              _buildEnhancedStatCard(
                                title: 'Paid Students',
                                count: _paidStudents,
                                icon: Icons.payment_rounded,
                                color: const Color(0xFF059669),
                                gradientColor: const Color(0xFF059669),
                                subtitle: 'Payment completed',
                                extraInfo: 'All time',
                              ),
                              const SizedBox(width: 10),
                              _buildEnhancedStatCard(
                                title: 'Pending Payment',
                                count: _pendingPaymentStudents,
                                icon: Icons.payment_outlined,
                                color: const Color(0xFFDC2626),
                                gradientColor: const Color(0xFFDC2626),
                                subtitle: 'Payment pending',
                                extraInfo: 'All time',
                              ),
                              const SizedBox(width: 10),
                              _buildEnhancedStatCard(
                                title: 'Subjects',
                                count: _teacherSubjects.length,
                                icon: Icons.book_rounded,
                                color: const Color(0xFFEC4899),
                                gradientColor: const Color(0xFFEC4899),
                                subtitle: 'Your subjects',
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          // Compact Current Month Payment Box
                          _buildCurrentMonthPaymentBox(),
                          const SizedBox(height: 24),
                          
                          // Academic Year Categories
                          if (_academicYears.isNotEmpty)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Students by Academic Year',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.darkText,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryPurple.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${_academicYears.length} Years',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primaryPurple,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                ..._academicYears.map((year) {
                                  return _buildAcademicYearBox(
                                    year, 
                                    _studentsByYear[year] ?? []
                                  );
                                }).toList(),
                              ],
                            )
                          else
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Text(
                                  'No students enrolled yet',
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          
                          const SizedBox(height: 24),
                          
                          // Recent Logins
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Recent Student Logins',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.darkText,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryPurple.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Last ${_recentEnrolledStudents.length}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primaryPurple,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_recentEnrolledStudents.isEmpty)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(40.0),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.history_rounded,
                                      size: 60,
                                      color: Colors.grey.shade300,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'No student logins recorded yet',
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      'Students will appear here after they log in',
                                      style: TextStyle(
                                        color: Colors.grey.shade400,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            Column(
                              children: _recentEnrolledStudents.map((student) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10.0),
                                  child: _buildRecentStudentCard(student),
                                );
                              }).toList(),
                            ),
                          // Bottom padding for scrollable content
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
                // FIXED BOTTOM FOOTER - Compact size (NON-SCROLLABLE)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.lightBackground,
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
              ],
            ),
    );
  }
}