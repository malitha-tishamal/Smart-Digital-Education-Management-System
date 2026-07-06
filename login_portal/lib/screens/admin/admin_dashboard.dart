import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/app_colors.dart';
import '../../auth/login_screen.dart';
import 'admin_drawer.dart';
import 'admin_profile.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isLoading = true;
  String _adminName = 'Admin';
  String _profileImageUrl = '';

  // Stats
  int _totalStudents = 0;
  int _totalAdmins = 0;
  int _totalTeachers = 0;
  int _totalStreams = 0;
  int _totalSubjects = 0;
  int _totalUsers = 0;
  List<Map<String, dynamic>> _recentUsers = [];

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
      _adminName = data['name'] ?? 'Admin';
      _profileImageUrl = data['profileImageUrl'] ?? _defaultProfileImageUrl;

      await _fetchStats();
    } catch (e) {
      print('Error loading admin data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchStats() async {
    try {
      final usersSnapshot = await _firestore.collection('users').get();

      final users = usersSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();

      _totalUsers = users.length;
      _totalStudents = users.where((u) => u['role'] == 'user').length;
      _totalAdmins = users.where((u) => u['role'] == 'admin').length;
      _totalTeachers = users.where((u) => u['role'] == 'teacher').length;

      final streams = <String>{};
      final subjects = <String>{};

      for (var user in users) {
        if (user['role'] != 'admin') {
          final stream = user['stream'] ?? '';
          if (stream.isNotEmpty) streams.add(stream);
          final userSubjects = List<String>.from(user['subjects'] ?? []);
          subjects.addAll(userSubjects);
        }
      }

      _totalStreams = streams.length;
      _totalSubjects = subjects.length;

      // Get recent 6 users by lastLoginAt
      final recentQuery = await _firestore
          .collection('users')
          .orderBy('lastLoginAt', descending: true)
          .limit(6)
          .get();

      _recentUsers = recentQuery.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final lastLogin = data['lastLoginAt'] as Timestamp?;
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Unknown',
          'email': data['email'] ?? 'No email',
          'role': data['role'] ?? 'user',
          'profileImageUrl': data['profileImageUrl'] ?? _defaultProfileImageUrl,
          'lastLoginAt': lastLogin?.toDate(),
          'status': data['status'] ?? 'pending',
          // 👇 Include student ID if present
          'studentId': data['studentId'] ?? '',
        };
      }).toList();
    } catch (e) {
      print('Error fetching stats: $e');
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
                    _adminName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Logged in as: Admin',
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
            'Admin Dashboard',
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
    return AdminDrawer(
      userName: _adminName,
      userRole: 'Admin',
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
          ],
        ),
      ),
    );
  }

  // ---- Recent User Card (Enhanced) ----
  Widget _buildEnhancedRecentUserCard(Map<String, dynamic> user) {
    String lastLoginText = 'Never logged in';
    if (user['lastLoginAt'] != null) {
      final now = DateTime.now();
      final diff = now.difference(user['lastLoginAt']);
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

    Color roleColor;
    Color roleBgColor;
    String roleLabel;
    IconData roleIcon;
    switch (user['role']) {
      case 'admin':
        roleColor = const Color(0xFF7C3AED);
        roleBgColor = const Color(0xFF7C3AED).withOpacity(0.1);
        roleLabel = 'Admin';
        roleIcon = Icons.admin_panel_settings;
        break;
      case 'teacher':
        roleColor = const Color(0xFF059669);
        roleBgColor = const Color(0xFF059669).withOpacity(0.1);
        roleLabel = 'Teacher';
        roleIcon = Icons.school;
        break;
      default:
        roleColor = const Color(0xFF2563EB);
        roleBgColor = const Color(0xFF2563EB).withOpacity(0.1);
        roleLabel = 'Student';
        roleIcon = Icons.person;
    }

    Color statusColor = user['status'] == 'Approved'
        ? const Color(0xFF059669)
        : (user['status'] == 'pending' ? const Color(0xFFF59E0B) : const Color(0xFFDC2626));

    // 👇 Get student ID if available
    final String studentId = user['studentId'] ?? '';
    final bool isStudent = user['role'] == 'user';

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
              backgroundImage: NetworkImage(user['profileImageUrl']),
              backgroundColor: Colors.grey.shade200,
              child: user['profileImageUrl'] == _defaultProfileImageUrl
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
                        user['name'],
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
                          color: roleBgColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(roleIcon, size: 12, color: roleColor),
                            const SizedBox(width: 3),
                            Text(
                              roleLabel,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: roleColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user['email'],
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          user['status'] ?? 'pending',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: statusColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 12, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(
                            lastLoginText,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // 👇 Display Student ID (only for students)
                  if (isStudent && studentId.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Icon(Icons.badge_outlined, size: 12, color: AppColors.primaryPurple),
                          const SizedBox(width: 4),
                          Text(
                            'ID: $studentId',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppColors.primaryPurple,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primaryPurple.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              
            ),
          ],
        ),
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
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadAdminData,
                    color: AppColors.primaryPurple,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Stats cards
                          Row(
                            children: [
                              _buildEnhancedStatCard(
                                title: 'Students',
                                count: _totalStudents,
                                icon: Icons.people_alt_rounded,
                                color: const Color(0xFF2563EB),
                                gradientColor: const Color(0xFF2563EB),
                                subtitle: 'Active learners',
                              ),
                              const SizedBox(width: 10),
                              _buildEnhancedStatCard(
                                title: 'Teachers',
                                count: _totalTeachers,
                                icon: Icons.school_rounded,
                                color: const Color(0xFF059669),
                                gradientColor: const Color(0xFF059669),
                                subtitle: 'Educators',
                              ),
                              const SizedBox(width: 10),
                              _buildEnhancedStatCard(
                                title: 'Admins',
                                count: _totalAdmins,
                                icon: Icons.admin_panel_settings_rounded,
                                color: const Color(0xFF7C3AED),
                                gradientColor: const Color(0xFF7C3AED),
                                subtitle: 'System admins',
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _buildEnhancedStatCard(
                                title: 'Total Users',
                                count: _totalUsers,
                                icon: Icons.people_rounded,
                                color: const Color(0xFFDC2626),
                                gradientColor: const Color(0xFFDC2626),
                                subtitle: 'All registered',
                              ),
                              const SizedBox(width: 10),
                              _buildEnhancedStatCard(
                                title: 'Streams',
                                count: _totalStreams,
                                icon: Icons.category_rounded,
                                color: const Color(0xFFF59E0B),
                                gradientColor: const Color(0xFFF59E0B),
                                subtitle: 'Available streams',
                              ),
                              const SizedBox(width: 10),
                              _buildEnhancedStatCard(
                                title: 'Subjects',
                                count: _totalSubjects,
                                icon: Icons.book_rounded,
                                color: const Color(0xFFEC4899),
                                gradientColor: const Color(0xFFEC4899),
                                subtitle: 'Total subjects',
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Recent Logins',
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
                                  'Last ${_recentUsers.length}',
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
                          if (_recentUsers.isEmpty)
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
                                      'No user logins recorded yet',
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      'Users will appear here after they log in',
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
                              children: _recentUsers.map((user) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10.0),
                                  child: _buildEnhancedRecentUserCard(user),
                                );
                              }).toList(),
                            ),
                          const SizedBox(height: 30),
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
}