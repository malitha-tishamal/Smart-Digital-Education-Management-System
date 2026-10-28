import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../core/app_config.dart';

class PasswordStrength {
  final bool hasMinLength;
  final bool hasUppercase;
  final bool hasLowercase;
  final bool hasDigit;
  final bool hasSpecial;

  const PasswordStrength({
    required this.hasMinLength,
    required this.hasUppercase,
    required this.hasLowercase,
    required this.hasDigit,
    required this.hasSpecial,
  });

  bool get isStrong =>
      hasMinLength && hasUppercase && hasLowercase && hasDigit && hasSpecial;
}

class LoginResult {
  final bool success;
  final String? errorMessage;
  final AppUser? user;
  final String? role;
  final bool isLocked;
  final DateTime? lockoutEnd;

  const LoginResult({
    required this.success,
    this.errorMessage,
    this.user,
    this.role,
    this.isLocked = false,
    this.lockoutEnd,
  });
}

class AuthController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ---------- Lockout helpers ----------
  int getLockoutDuration(int attempts) {
    switch (attempts) {
      case 3:
        return 30;
      case 4:
        return 60;
      case 5:
        return 180;
      case 6:
        return 600;
      case 7:
        return 1800;
      default:
        return 0;
    }
  }

  Future<DocumentSnapshot?> getUserDocByEmail(String email) async {
    try {
      final query = await _firestore
          .collection(AppConfig.usersCollection)
          .where('email', isEqualTo: email.trim().toLowerCase())
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) return query.docs.first;

      // Also try original case
      final fallbackQuery = await _firestore
          .collection(AppConfig.usersCollection)
          .where('email', isEqualTo: email.trim())
          .limit(1)
          .get();
      return fallbackQuery.docs.isNotEmpty ? fallbackQuery.docs.first : null;
    } catch (e) {
      debugPrint('Error fetching user by email: $e');
      return null;
    }
  }

  Future<void> recordFailedAttempt(String email) async {
    final userDoc = await getUserDocByEmail(email);
    if (userDoc == null) return;
    final data = userDoc.data() as Map<String, dynamic>;
    int attempts = (data['failedLoginAttempts'] ?? 0) + 1;
    String status = data['status'] ?? 'pending';
    Timestamp? lockoutUntil;

    if (status == 'Locked') return;

    if (attempts >= 8) {
      status = 'Locked';
      lockoutUntil = null;
    } else {
      final duration = getLockoutDuration(attempts);
      if (duration > 0) {
        lockoutUntil = Timestamp.fromDate(
          DateTime.now().add(Duration(seconds: duration)),
        );
      }
    }

    await userDoc.reference.update({
      'failedLoginAttempts': attempts,
      'lockoutUntil': lockoutUntil,
      'status': status,
    });
  }

  Future<void> resetFailedAttempts(String email) async {
    final userDoc = await getUserDocByEmail(email);
    if (userDoc == null) return;
    await userDoc.reference.update({
      'failedLoginAttempts': 0,
      'lockoutUntil': null,
    });
  }

  Future<({bool isLocked, String? message, DateTime? lockoutEnd})> checkLockoutStatus(
    String email,
  ) async {
    final userDoc = await getUserDocByEmail(email);
    if (userDoc == null) return (isLocked: false, message: null, lockoutEnd: null);

    final data = userDoc.data() as Map<String, dynamic>;
    final status = data['status'] as String? ?? 'pending';
    final lockoutUntil = data['lockoutUntil'] as Timestamp?;

    if (status == 'Locked') {
      return (
        isLocked: true,
        message: 'Your account has been locked. Please contact admin for approval.',
        lockoutEnd: null,
      );
    }

    if (lockoutUntil != null) {
      final lockoutDateTime = lockoutUntil.toDate();
      if (lockoutDateTime.isAfter(DateTime.now())) {
        return (
          isLocked: true,
          message: 'Too many failed attempts. Try again later.',
          lockoutEnd: lockoutDateTime,
        );
      } else {
        await userDoc.reference.update({'lockoutUntil': null});
      }
    }
    return (isLocked: false, message: null, lockoutEnd: null);
  }

  Future<void> updateLastLogin(String uid) async {
    try {
      await _firestore.collection(AppConfig.usersCollection).doc(uid).update({
        'lastLoginAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Failed to update lastLoginAt: $e');
    }
  }

  // ---------- Sign In ----------
  Future<LoginResult> signIn({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty || password.isEmpty) {
      return const LoginResult(
        success: false,
        errorMessage: 'Please enter both email and password.',
      );
    }

    final lockout = await checkLockoutStatus(cleanEmail);
    if (lockout.isLocked) {
      return LoginResult(
        success: false,
        errorMessage: lockout.message,
        isLocked: true,
        lockoutEnd: lockout.lockoutEnd,
      );
    }

    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );
      final user = userCredential.user;
      if (user == null) {
        return const LoginResult(
          success: false,
          errorMessage: 'User object is null.',
        );
      }

      final userDoc = await _firestore
          .collection(AppConfig.usersCollection)
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        await _auth.signOut();
        return const LoginResult(
          success: false,
          errorMessage: 'User profile not found. Contact support.',
        );
      }

      final appUser = AppUser.fromFirestore(userDoc);
      final accountStatus = appUser.status;

      if (accountStatus != 'Approved') {
        await _auth.signOut();
        return LoginResult(
          success: false,
          errorMessage: 'Your account status is "$accountStatus". Access restricted.',
        );
      }

      // Successful login: reset failed attempts & update last login
      await resetFailedAttempts(cleanEmail);
      await updateLastLogin(user.uid);

      return LoginResult(
        success: true,
        user: appUser,
        role: appUser.role,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        await recordFailedAttempt(cleanEmail);
        final newLockout = await checkLockoutStatus(cleanEmail);
        if (newLockout.isLocked) {
          return LoginResult(
            success: false,
            errorMessage: newLockout.message,
            isLocked: true,
            lockoutEnd: newLockout.lockoutEnd,
          );
        }
        return const LoginResult(
          success: false,
          errorMessage: 'Invalid email or password.',
        );
      } else if (e.code == 'user-not-found') {
        return const LoginResult(
          success: false,
          errorMessage: 'Invalid email or password.',
        );
      } else {
        return LoginResult(
          success: false,
          errorMessage: e.message ?? 'Authentication failed.',
        );
      }
    } catch (e) {
      return LoginResult(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }

  // ---------- Password Strength ----------
  PasswordStrength calculatePasswordStrength(String password) {
    return PasswordStrength(
      hasMinLength: password.length >= 8,
      hasUppercase: password.contains(RegExp(r'[A-Z]')),
      hasLowercase: password.contains(RegExp(r'[a-z]')),
      hasDigit: password.contains(RegExp(r'[0-9]')),
      hasSpecial: password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]')),
    );
  }

  // ---------- Student ID Generation ----------
  Future<String> generateStudentId({
    required String stream,
    required String role,
  }) async {
    if (role != 'user' || stream.isEmpty) return '';

    try {
      final counterRef = _firestore
          .collection(AppConfig.countersCollection)
          .doc('studentIdCounter');

      final int newNumber = await _firestore.runTransaction<int>(
        (transaction) async {
          final counterDoc = await transaction.get(counterRef);
          int currentCount = 0;
          if (counterDoc.exists) {
            currentCount = counterDoc.data()?['count'] ?? 0;
          }
          final newCount = currentCount + 1;
          transaction.set(
            counterRef,
            {'count': newCount},
            SetOptions(merge: true),
          );
          return newCount;
        },
      );

      final currentYear = DateTime.now().year;
      final sequence = newNumber.toString().padLeft(4, '0');
      final streamCode = stream.isNotEmpty
          ? stream.substring(0, stream.length >= 3 ? 3 : stream.length).toUpperCase()
          : 'GEN';

      return '$streamCode-$currentYear-$sequence';
    } catch (e) {
      debugPrint('Error generating student ID: $e');
      return '';
    }
  }

  // ---------- Sign Up ----------
  Future<AppUser?> signUp({
    required String email,
    required String password,
    required String name,
    required String nic,
    required String mobile,
    required String role,
    required String stream,
    required List<String> subjects,
    String alYear = '',
    String studentId = '',
  }) async {
    final cleanEmail = email.trim();
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: cleanEmail,
      password: password,
    );

    final user = userCredential.user;
    if (user == null) return null;

    final appUser = AppUser(
      uid: user.uid,
      email: cleanEmail,
      name: name.trim(),
      nic: nic.trim().toUpperCase(),
      mobile: mobile.trim(),
      role: role,
      stream: stream,
      subjects: subjects,
      status: 'pending',
      alYear: alYear,
      studentId: studentId,
      profileImageUrl: AppConfig.defaultProfileImageUrl,
      createdAt: DateTime.now(),
    );

    await _firestore
        .collection(AppConfig.usersCollection)
        .doc(user.uid)
        .set(appUser.toMap());

    return appUser;
  }

  // ---------- Forgot Password ----------
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  // ---------- Sign Out ----------
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // ---------- Role & Profile Fetch ----------
  Future<String?> getCurrentUserRole() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final doc = await _firestore
          .collection(AppConfig.usersCollection)
          .doc(user.uid)
          .get();
      if (doc.exists) {
        return (doc.data() as Map<String, dynamic>?)?['role'] as String? ?? 'user';
      }
    } catch (e) {
      debugPrint('Error fetching user role: $e');
    }
    return null;
  }

  Future<AppUser?> getCurrentUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final doc = await _firestore
          .collection(AppConfig.usersCollection)
          .doc(user.uid)
          .get();
      if (doc.exists) {
        return AppUser.fromFirestore(doc);
      }
    } catch (e) {
      debugPrint('Error fetching current user profile: $e');
    }
    return null;
  }
}
