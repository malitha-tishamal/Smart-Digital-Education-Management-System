import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/app_colors.dart';
import '../auth/login_screen.dart';
import 'student_drawer.dart';
import 'class_detail_screen.dart';

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
  List<Map<String, dynamic>> _teachers = [];

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

      await _findMatchingTeachers();
    } catch (e) {
      print('Error loading student data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _findMatchingTeachers() async {
    if (_studentStream.isEmpty || _studentSubjects.isEmpty) {
      _teachers = [];
      return;
    }

    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'teacher')
          .where('stream', isEqualTo: _studentStream)
          .get();

      final allTeachers = querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'uid': doc.id,
          'name': data['name'] ?? 'Teacher',
          'email': data['email'] ?? '',
          'stream': data['stream'] ?? '',
          'subjects': List<String>.from(data['subjects'] ?? []),
          'profileImageUrl': data['profileImageUrl'] ?? _defaultProfileImageUrl,
        };
      }).toList();

      // Filter teachers whose subjects include all of the student's subjects
      _teachers = allTeachers.where((teacher) {
        final teacherSubjects = teacher['subjects'] as List<String>;
        return _studentSubjects.every((s) => teacherSubjects.contains(s));
      }).toList();
    } catch (e) {
      print('Error finding teachers: $e');
      _teachers = [];
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

  // ---- Header (same as before) ----
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
                    _studentName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Logged in as: Student',
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
            'My Classes',
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
    return StudentDrawer(
      userName: _studentName,
      userEmail: _auth.currentUser?.email ?? 'student@example.com',
      profileImageUrl: _profileImageUrl,
      onLogout: () => _logout(context),
    );
  }

  // ---- Class Card with "Visit" button ----
  Widget _buildClassCard(Map<String, dynamic> teacher) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 35,
              backgroundImage: NetworkImage(teacher['profileImageUrl']),
              backgroundColor: Colors.grey.shade200,
              child: teacher['profileImageUrl'] == _defaultProfileImageUrl
                  ? const Icon(Icons.person, size: 35, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    teacher['name'],
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Stream: ${teacher['stream']}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: (teacher['subjects'] as List<String>).map((subject) {
                      return Chip(
                        label: Text(subject),
                        backgroundColor: Colors.grey.shade100,
                        labelStyle: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            // ---- VISIT BUTTON ----
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ClassDetailScreen(teacher: teacher),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: const Text('Visit'),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Empty state ----
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.class_, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'No classes found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You are not assigned to any class yet.\nPlease contact your admin.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
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
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadStudentData,
                    color: AppColors.primaryPurple,
                    child: _teachers.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.all(16.0),
                            itemCount: _teachers.length,
                            itemBuilder: (context, index) {
                              return _buildClassCard(_teachers[index]);
                            },
                          ),
                  ),
                ),
              ],
            ),
    );
  }
}