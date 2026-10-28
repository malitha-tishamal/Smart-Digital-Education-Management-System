import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../core/app_config.dart';

class UserController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _usersCollection =>
      _firestore.collection(AppConfig.usersCollection);

  /// Stream of all users
  Stream<List<AppUser>> streamAllUsers() {
    return _usersCollection.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => AppUser.fromFirestore(doc)).toList());
  }

  /// Stream of users filtered by role ('admin', 'teacher', 'user')
  Stream<List<AppUser>> streamUsersByRole(String role) {
    return _usersCollection
        .where('role', isEqualTo: role)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => AppUser.fromFirestore(doc)).toList());
  }

  /// Update user account status ('Approved', 'pending', 'Locked', 'Disabled')
  Future<void> updateUserStatus(String uid, String status) async {
    final Map<String, dynamic> updateData = {
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (status == 'Approved') {
      updateData['failedLoginAttempts'] = 0;
      updateData['lockoutUntil'] = null;
    }
    await _usersCollection.doc(uid).update(updateData);
  }

  /// Update user role ('admin', 'teacher', 'user')
  Future<void> updateUserRole(String uid, String role) async {
    await _usersCollection.doc(uid).update({
      'role': role,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Update user profile details
  Future<void> updateUserDetails({
    required String uid,
    required String name,
    required String mobile,
    required String nic,
    String? profileImageUrl,
    String? stream,
    List<String>? subjects,
    String? alYear,
  }) async {
    final Map<String, dynamic> updateData = {
      'name': name.trim(),
      'mobile': mobile.trim(),
      'nic': nic.trim().toUpperCase(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (profileImageUrl != null) {
      updateData['profileImageUrl'] = profileImageUrl;
    }
    if (stream != null) {
      updateData['stream'] = stream;
    }
    if (subjects != null) {
      updateData['subjects'] = subjects;
    }
    if (alYear != null) {
      updateData['alYear'] = alYear;
    }

    await _usersCollection.doc(uid).update(updateData);
  }

  /// Delete a user record from Firestore
  Future<void> deleteUser(String uid) async {
    await _usersCollection.doc(uid).delete();
  }

  /// Fetch a single user by UID
  Future<AppUser?> getUserById(String uid) async {
    final doc = await _usersCollection.doc(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromFirestore(doc);
  }
}
