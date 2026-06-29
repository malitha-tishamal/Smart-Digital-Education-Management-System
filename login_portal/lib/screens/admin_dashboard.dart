import 'package:flutter/material.dart';
import '../models/user_model.dart';
import 'package:intl/intl.dart';
import '../auth_service.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final AuthService _auth = AuthService();
  AppUser? _currentUser;
  String _currentTime = '';

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _updateTime();
  }

  Future<void> _loadUserProfile() async {
    final user = _auth.authStateChanges;
    user.listen((firebaseUser) async {
      if (firebaseUser != null) {
        final appUser = await _auth.getUserProfile(firebaseUser.uid);
        if (mounted) {
          setState(() {
            _currentUser = appUser;
          });
        }
      }
    });
  }

  void _updateTime() {
    setState(() {
      _currentTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _auth.signOut();
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Welcome, ${_currentUser?.name ?? 'Admin'}!',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 20),
              Text(
                'Role: Admin',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 20),
              Text(
                'Current Time: $_currentTime',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              const Text(
                'This is the Admin dashboard. You have access to administrative functions.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _updateTime,
                child: const Text('Refresh Time'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}